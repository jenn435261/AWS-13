package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	resiliencev1 "github.com/resilience-network/aws13/cloud/gen/resilience/v1"
	"github.com/resilience-network/aws13/cloud/internal/events"
	"google.golang.org/protobuf/proto"

	// pgx stdlib driver registers the "pgx" database/sql driver.
	_ "github.com/jackc/pgx/v5/stdlib"
)

// PostgresStore is a Store backed by PostgreSQL (with optional PostGIS for geo
// queries). It verifies every event before storing (verify-before-store) and
// dedups by content hash via the events primary key.
//
// The whole raw SignedEvent is persisted in the `raw` column (deterministic
// protobuf) so pulls can return the exact bytes the author signed; the header
// fields are also projected into typed columns for indexing and geo queries.
type PostgresStore struct {
	db *sql.DB
}

var _ Store = (*PostgresStore)(nil)

// OpenPostgres opens a PostgresStore from a DSN (e.g.
// "postgres://user:pass@host:5432/db?sslmode=disable"). It does not run
// migrations; call Migrate for that.
func OpenPostgres(dsn string) (*PostgresStore, error) {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, fmt.Errorf("open postgres: %w", err)
	}
	return &PostgresStore{db: db}, nil
}

// NewPostgresStore wraps an existing *sql.DB (useful for sharing a pool).
func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{db: db}
}

// Close releases the underlying pool.
func (p *PostgresStore) Close() error { return p.db.Close() }

// Ping verifies connectivity (used by readiness checks).
func (p *PostgresStore) Ping(ctx context.Context) error { return p.db.PingContext(ctx) }

// migrateSQL creates the PostGIS extension, the events table, a geography point
// column populated from the event's GeoPoint when present, and indexes
// (including a GIST index on the geography) so "resources within N km" geo
// queries are possible later.
const migrateSQL = `
-- postgis: enables geography types + GIST spatial indexing for geo queries.
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS events (
    event_id      bytea PRIMARY KEY,
    type          int    NOT NULL,
    author_pubkey bytea  NOT NULL,
    lamport       bigint NOT NULL,
    prev_event_id bytea,
    created_at_ms bigint NOT NULL,
    h3_cell       bigint,
    raw           bytea  NOT NULL,
    valid         bool   NOT NULL,
    geog          geography(Point,4326)
);

CREATE INDEX IF NOT EXISTS events_author_lamport_idx
    ON events (author_pubkey, lamport);

CREATE INDEX IF NOT EXISTS events_h3_idx
    ON events (h3_cell);

CREATE INDEX IF NOT EXISTS events_geog_gist
    ON events USING GIST (geog);
`

// Migrate creates the extension and schema. Safe to run repeatedly.
func (p *PostgresStore) Migrate(ctx context.Context) error {
	if _, err := p.db.ExecContext(ctx, migrateSQL); err != nil {
		return fmt.Errorf("migrate: %w", err)
	}
	return nil
}

// Push verifies and stores each event. Invalid events are returned in rejected
// and never stored. Dedup is by the event_id primary key (ON CONFLICT DO
// NOTHING); a re-pushed event still counts as applied.
func (p *PostgresStore) Push(ctx context.Context, evs []*resiliencev1.SignedEvent) (applied [][]byte, rejected [][]byte, err error) {
	tx, err := p.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	const insertSQL = `
INSERT INTO events
    (event_id, type, author_pubkey, lamport, prev_event_id, created_at_ms, h3_cell, raw, valid, geog)
VALUES
    ($1, $2, $3, $4, $5, $6, $7, $8, true,
     CASE WHEN $9::bool THEN ST_SetSRID(ST_MakePoint($10::float8, $11::float8), 4326)::geography ELSE NULL END)
ON CONFLICT (event_id) DO NOTHING;`

	for _, ev := range evs {
		ok, _ := events.VerifyEvent(ev)
		if !ok {
			rejected = append(rejected, eventID(ev))
			continue
		}
		h := ev.GetHeader()
		raw, merr := proto.MarshalOptions{Deterministic: true}.Marshal(ev)
		if merr != nil {
			rejected = append(rejected, h.GetEventId())
			continue
		}

		hasGeo, lat, lon := eventLatLon(ev)

		var h3 sql.NullInt64
		if h.GetH3Cell() != 0 {
			h3 = sql.NullInt64{Int64: int64(h.GetH3Cell()), Valid: true}
		}
		var prev []byte
		if len(h.GetPrevEventId()) > 0 {
			prev = h.GetPrevEventId()
		}

		if _, eerr := tx.ExecContext(ctx, insertSQL,
			h.GetEventId(),
			int(h.GetType()),
			h.GetAuthorPubkey(),
			int64(h.GetLamport()),
			prev,
			h.GetCreatedAtMs(),
			h3,
			raw,
			hasGeo,
			lat,
			lon,
		); eerr != nil {
			return nil, nil, fmt.Errorf("insert event: %w", eerr)
		}
		applied = append(applied, h.GetEventId())
	}

	if cerr := tx.Commit(); cerr != nil {
		return nil, nil, fmt.Errorf("commit: %w", cerr)
	}
	return applied, rejected, nil
}

// PullByAuthorFrom returns stored events with lamport strictly greater than the
// supplied watermark per author. When from is empty, all events are returned,
// ordered by (author_pubkey, lamport, event_id). limit <= 0 means no limit.
func (p *PostgresStore) PullByAuthorFrom(ctx context.Context, from map[string]uint64, limit int) ([]*resiliencev1.SignedEvent, error) {
	var (
		query string
		args  []any
	)
	if len(from) == 0 {
		query = `SELECT raw FROM events ORDER BY author_pubkey, lamport, event_id`
	} else {
		// Build an OR of (author = $k AND lamport > $k+1) clauses.
		query = `SELECT raw FROM events WHERE `
		i := 1
		first := true
		for authorHex, wm := range from {
			authorBytes, derr := hexDecode(authorHex)
			if derr != nil {
				return nil, fmt.Errorf("bad author key %q: %w", authorHex, derr)
			}
			if !first {
				query += " OR "
			}
			first = false
			query += fmt.Sprintf("(author_pubkey = $%d AND lamport > $%d)", i, i+1)
			args = append(args, authorBytes, int64(wm))
			i += 2
		}
		query += ` ORDER BY author_pubkey, lamport, event_id`
	}
	if limit > 0 {
		query += fmt.Sprintf(" LIMIT %d", limit)
	}

	rows, err := p.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("pull query: %w", err)
	}
	defer rows.Close()

	var out []*resiliencev1.SignedEvent
	for rows.Next() {
		var raw []byte
		if serr := rows.Scan(&raw); serr != nil {
			return nil, fmt.Errorf("scan: %w", serr)
		}
		ev := &resiliencev1.SignedEvent{}
		if uerr := proto.Unmarshal(raw, ev); uerr != nil {
			return nil, fmt.Errorf("unmarshal raw: %w", uerr)
		}
		out = append(out, ev)
	}
	return out, rows.Err()
}

// HighWaterByAuthor returns the max lamport per author.
func (p *PostgresStore) HighWaterByAuthor(ctx context.Context) (map[string]uint64, error) {
	rows, err := p.db.QueryContext(ctx,
		`SELECT author_pubkey, MAX(lamport) FROM events GROUP BY author_pubkey`)
	if err != nil {
		return nil, fmt.Errorf("highwater query: %w", err)
	}
	defer rows.Close()

	out := make(map[string]uint64)
	for rows.Next() {
		var author []byte
		var hw int64
		if serr := rows.Scan(&author, &hw); serr != nil {
			return nil, fmt.Errorf("scan: %w", serr)
		}
		out[AuthorKey(author)] = uint64(hw)
	}
	return out, rows.Err()
}

// Get returns the event with the given id.
func (p *PostgresStore) Get(ctx context.Context, id []byte) (*resiliencev1.SignedEvent, bool, error) {
	var raw []byte
	err := p.db.QueryRowContext(ctx, `SELECT raw FROM events WHERE event_id = $1`, id).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("get query: %w", err)
	}
	ev := &resiliencev1.SignedEvent{}
	if uerr := proto.Unmarshal(raw, ev); uerr != nil {
		return nil, false, fmt.Errorf("unmarshal raw: %w", uerr)
	}
	return ev, true, nil
}
