// Command resilience-node is the Resilience Node daemon: a local event cache +
// sync server + offline web app + package/map server + optional cloud/mesh
// gateway. It is designed to run on a small Linux box (e.g. a Raspberry Pi
// acting as a Wi-Fi access point) so phones can reconcile through it with no
// internet. See node/README.md for deployment.
package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/resilience-network/aws13/node/internal/cache"
	"github.com/resilience-network/aws13/node/internal/gateway"
	"github.com/resilience-network/aws13/node/internal/packages"
	"github.com/resilience-network/aws13/node/internal/syncserver"
	"github.com/resilience-network/aws13/node/internal/webapp"
)

// config is the resolved daemon configuration (flags override env).
type config struct {
	httpAddr     string
	dataDir      string
	cloudBaseURL string
	apkDir       string
	mapDir       string
	readinessDir string
	syncInterval time.Duration
}

func loadConfig() config {
	c := config{
		httpAddr:     envOr("HTTP_ADDR", ":8090"),
		dataDir:      envOr("DATA_DIR", ""),
		cloudBaseURL: strings.TrimSpace(os.Getenv("CLOUD_BASE_URL")),
		apkDir:       envOr("APK_DIR", ""),
		mapDir:       envOr("MAP_DIR", ""),
		readinessDir: envOr("READINESS_DIR", ""),
		syncInterval: 15 * time.Second,
	}
	flag.StringVar(&c.httpAddr, "http-addr", c.httpAddr, "HTTP listen address (env HTTP_ADDR)")
	flag.StringVar(&c.dataDir, "data-dir", c.dataDir, "directory for the append-only event log (env DATA_DIR); empty = in-memory only")
	flag.StringVar(&c.cloudBaseURL, "cloud-base-url", c.cloudBaseURL, "upstream cloud base URL (env CLOUD_BASE_URL); empty = offline only")
	flag.StringVar(&c.apkDir, "apk-dir", c.apkDir, "directory containing the Android APK (env APK_DIR)")
	flag.StringVar(&c.mapDir, "map-dir", c.mapDir, "directory containing <region>.pmtiles maps (env MAP_DIR)")
	flag.StringVar(&c.readinessDir, "readiness-dir", c.readinessDir, "directory containing readiness bundles (env READINESS_DIR)")
	flag.DurationVar(&c.syncInterval, "sync-interval", c.syncInterval, "cloud/mesh sync cadence")
	flag.Parse()
	return c
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	cfg := loadConfig()
	if err := run(cfg, logger); err != nil {
		logger.Error("node exited with error", "err", err)
		os.Exit(1)
	}
}

func run(cfg config, logger *slog.Logger) error {
	// Event cache (optionally persisted to an append-only log under DATA_DIR).
	var (
		store *cache.Cache
		err   error
	)
	logPath := ""
	if cfg.dataDir != "" {
		if mkErr := os.MkdirAll(cfg.dataDir, 0o755); mkErr != nil {
			return mkErr
		}
		logPath = cfg.dataDir + string(os.PathSeparator) + "events.log"
	}
	store, err = cache.Open(logPath)
	if err != nil {
		return err
	}
	defer store.Close()

	// HTTP surface: sync endpoints + web app + package server on one mux.
	mux := http.NewServeMux()
	sync := syncserver.New(store)
	sync.Register(mux) // includes /healthz
	pkg := packages.New(packages.Config{
		APKDir:       cfg.apkDir,
		MapDir:       cfg.mapDir,
		ReadinessDir: cfg.readinessDir,
	})
	pkg.Register(mux)
	mux.Handle("/", webapp.Handler())

	srv := &http.Server{
		Addr:              cfg.httpAddr,
		Handler:           logRequests(logger, mux),
		ReadHeaderTimeout: 10 * time.Second,
	}

	// Root context cancelled on SIGINT/SIGTERM for graceful shutdown.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	// Gateway loop (cloud optional; mesh defaults to the no-op bridge).
	var cloud gateway.CloudClient
	if cfg.cloudBaseURL != "" {
		cloud = gateway.NewHTTPCloud(cfg.cloudBaseURL)
	}
	gw := gateway.New(store, gateway.Options{
		Cloud:    cloud,
		Interval: cfg.syncInterval,
		Logger:   logger,
	})
	go func() {
		if gwErr := gw.Run(ctx); gwErr != nil {
			logger.Error("gateway loop error", "err", gwErr)
		}
	}()

	// Serve.
	serveErr := make(chan error, 1)
	go func() {
		logger.Info("resilience-node listening",
			"addr", cfg.httpAddr,
			"cloud_enabled", cloud != nil,
			"data_dir", cfg.dataDir,
		)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
			return
		}
		serveErr <- nil
	}()

	select {
	case err := <-serveErr:
		return err
	case <-ctx.Done():
		logger.Info("shutdown signal received, draining")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			return err
		}
		logger.Info("node stopped cleanly")
		return nil
	}
}

// logRequests is lightweight structured access logging middleware.
func logRequests(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sw, r)
		logger.Info("http",
			"method", r.Method,
			"path", r.URL.Path,
			"status", sw.status,
			"dur_ms", time.Since(start).Milliseconds(),
		)
	})
}

type statusWriter struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func (s *statusWriter) WriteHeader(code int) {
	if !s.wroteHeader {
		s.status = code
		s.wroteHeader = true
	}
	s.ResponseWriter.WriteHeader(code)
}

func (s *statusWriter) Write(b []byte) (int, error) {
	if !s.wroteHeader {
		s.wroteHeader = true
	}
	return s.ResponseWriter.Write(b)
}

func envOr(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}
