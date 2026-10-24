// Command resilience-node is the Resilience Node daemon: a local event cache +
// sync server + offline web app + package/map server + optional cloud/mesh
// gateway. It is designed to run on a small Linux box (e.g. a Raspberry Pi
// acting as a Wi-Fi access point) so phones can reconcile through it with no
// internet. See node/README.md for deployment.
package main

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
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
	"github.com/resilience-network/aws13/node/internal/pairing"
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
	name         string
	publicURL    string
	signingKey   string
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
		name:         envOr("NODE_NAME", "Resilience Node"),
		publicURL:    envOr("PUBLIC_URL", ""),
		signingKey:   envOr("PACKAGES_SIGNING_KEY", ""),
		syncInterval: 15 * time.Second,
	}
	flag.StringVar(&c.httpAddr, "http-addr", c.httpAddr, "HTTP listen address (env HTTP_ADDR)")
	flag.StringVar(&c.dataDir, "data-dir", c.dataDir, "directory for the append-only event log (env DATA_DIR); empty = in-memory only")
	flag.StringVar(&c.cloudBaseURL, "cloud-base-url", c.cloudBaseURL, "upstream cloud base URL (env CLOUD_BASE_URL); empty = offline only")
	flag.StringVar(&c.apkDir, "apk-dir", c.apkDir, "directory containing the Android APK (env APK_DIR)")
	flag.StringVar(&c.mapDir, "map-dir", c.mapDir, "directory containing <region>.pmtiles maps (env MAP_DIR)")
	flag.StringVar(&c.readinessDir, "readiness-dir", c.readinessDir, "directory containing readiness bundles (env READINESS_DIR)")
	flag.StringVar(&c.name, "name", c.name, "display name shown to phones that pair with this node (env NODE_NAME)")
	flag.StringVar(&c.publicURL, "public-url", c.publicURL, "address advertised in the pairing QR; default is the address the phone used (env PUBLIC_URL)")
	flag.StringVar(&c.signingKey, "packages-signing-key", c.signingKey, "path to a hex-encoded Ed25519 private key (64 bytes) or seed (32 bytes) used to sign the package manifest (env PACKAGES_SIGNING_KEY); empty disables the signed manifest endpoint")
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
	if cfg.signingKey != "" {
		priv, kerr := loadSigningKey(cfg.signingKey)
		if kerr != nil {
			return kerr
		}
		pkg.WithSigningKey(priv)
		logger.Info("package manifest signing enabled",
			"pubkey", hex.EncodeToString(priv.Public().(ed25519.PublicKey)))
	}
	pkg.Register(mux)
	pairing.New(pairing.Config{Name: cfg.name, PublicURL: cfg.publicURL}).Register(mux)
	mux.Handle("/", webapp.Handler())

	srv := &http.Server{
		Addr:              cfg.httpAddr,
		Handler:           cors(logRequests(logger, mux)),
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

// cors lets the web build (served from another origin, e.g. the cloud API's
// https page) read this node. The node serves public, non-secret data (node
// state is signed events; packages are public files) and carries no cookies,
// so a wildcard origin does not widen what an attacker can reach.
func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Access-Control-Allow-Origin", "*")
		h.Set("Access-Control-Allow-Methods", "GET, HEAD, POST, OPTIONS")
		h.Set("Access-Control-Allow-Headers", "Content-Type, Range")
		h.Set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges")
		h.Set("Access-Control-Allow-Private-Network", "true")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
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

// loadSigningKey reads a hex-encoded Ed25519 key from path. It accepts either a
// 64-byte private key (128 hex chars) or a 32-byte seed (64 hex chars), from
// which the full private key is derived. Whitespace is trimmed.
func loadSigningKey(path string) (ed25519.PrivateKey, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read signing key: %w", err)
	}
	decoded, err := hex.DecodeString(strings.TrimSpace(string(raw)))
	if err != nil {
		return nil, fmt.Errorf("decode signing key hex: %w", err)
	}
	switch len(decoded) {
	case ed25519.PrivateKeySize:
		return ed25519.PrivateKey(decoded), nil
	case ed25519.SeedSize:
		return ed25519.NewKeyFromSeed(decoded), nil
	default:
		return nil, fmt.Errorf("signing key must be %d-byte key or %d-byte seed, got %d bytes",
			ed25519.PrivateKeySize, ed25519.SeedSize, len(decoded))
	}
}

func envOr(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}
