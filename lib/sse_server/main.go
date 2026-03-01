package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

const pollInterval = 100 * time.Millisecond

func main() {
	dbPath := os.Getenv("CABLE_DB_PATH")
	if dbPath == "" {
		dbPath = "storage/development_cable.sqlite3"
	}

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	defer db.Close()

	// WAL mode lets the Go server read while Rails writes concurrently.
	if _, err := db.Exec("PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;"); err != nil {
		log.Printf("pragma: %v", err)
	}

	addr := os.Getenv("SSE_ADDR")
	if addr == "" {
		addr = ":4000"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/sse", func(w http.ResponseWriter, r *http.Request) {
		sseHandler(w, r, db)
	})

	log.Printf("SSE server listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func sseHandler(w http.ResponseWriter, r *http.Request, db *sql.DB) {
	channel := r.URL.Query().Get("channel")
	if channel == "" {
		http.Error(w, "channel parameter required", http.StatusBadRequest)
		return
	}

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	h := w.Header()
	h.Set("Content-Type", "text/event-stream")
	h.Set("Cache-Control", "no-cache")
	h.Set("Connection", "keep-alive")
	h.Set("X-Accel-Buffering", "no") // tell nginx not to buffer SSE
	h.Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusOK)
	flusher.Flush()

	ctx := r.Context()

	// Fresh connection: start from the current max so we don't replay history
	// that Rails already rendered server-side.
	// Reconnection: browser sends Last-Event-ID and we replay only what was
	// missed while the connection was down.
	var lastID int64
	if raw := r.Header.Get("Last-Event-ID"); raw != "" {
		if id, err := strconv.ParseInt(raw, 10, 64); err == nil {
			lastID = id
		}
	} else {
		db.QueryRowContext(ctx, "SELECT COALESCE(MAX(id), 0) FROM solid_cable_messages").Scan(&lastID)
	}

	log.Printf("client connected  channel=%.40s… last_id=%d", channel, lastID)
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Printf("client disconnected last_id=%d", lastID)
			return
		case <-ticker.C:
			// channel is stored as a BINARY blob; pass []byte so SQLite
			// compares blob-to-blob rather than text-to-blob.
			rows, err := db.QueryContext(ctx,
				`SELECT id, payload FROM solid_cable_messages
				  WHERE channel = ? AND id > ?
				  ORDER BY id ASC`,
				[]byte(channel), lastID,
			)
			if err != nil {
				if ctx.Err() != nil {
					return
				}
				log.Printf("query error: %v", err)
				continue
			}

			for rows.Next() {
				var id int64
				var payload []byte
				if err := rows.Scan(&id, &payload); err != nil {
					log.Printf("scan error: %v", err)
					continue
				}

				html, err := extractTurboHTML(payload)
				if err != nil {
					log.Printf("payload parse error (id=%d): %v — raw: %s", id, err, payload)
					lastID = id
					continue
				}

				writeSSEEvent(w, id, html)
				lastID = id
			}
			rows.Close()
			flusher.Flush()
		}
	}
}

// extractTurboHTML pulls the Turbo stream HTML out of the SolidCable payload.
// SolidCable stores the payload as a plain JSON string: "<turbo-stream ...>"
// Fall back to trying a {"data":"..."} object in case the format ever changes.
func extractTurboHTML(payload []byte) (string, error) {
	// Fast path: plain JSON string (the common case).
	var html string
	if err := json.Unmarshal(payload, &html); err == nil {
		return html, nil
	}

	// Slow path: JSON object with a "data" or "message" key.
	var msg map[string]json.RawMessage
	if err := json.Unmarshal(payload, &msg); err != nil {
		return "", fmt.Errorf("unmarshal: %w", err)
	}
	for _, key := range []string{"data", "message"} {
		if raw, ok := msg[key]; ok {
			var s string
			if err := json.Unmarshal(raw, &s); err != nil {
				return "", fmt.Errorf("unmarshal %q value: %w", key, err)
			}
			return s, nil
		}
	}
	return "", fmt.Errorf("unrecognised payload shape: %s", payload)
}

// writeSSEEvent writes one SSE event. Multi-line data is handled per spec:
// each newline becomes a new "data:" line.
func writeSSEEvent(w http.ResponseWriter, id int64, data string) {
	fmt.Fprintf(w, "id: %d\n", id)
	for _, line := range strings.Split(data, "\n") {
		fmt.Fprintf(w, "data: %s\n", line)
	}
	fmt.Fprintln(w) // blank line terminates the event
}
