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
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

const (
	pollInterval = 10 * time.Millisecond
	bufferSize   = 200
)

// message is a decoded SSE event ready to send to clients.
type message struct {
	id   int64
	html string
}

// broadcaster runs a single poll loop and fans out to all connected clients.
type broadcaster struct {
	db      *sql.DB
	channel []byte

	mu       sync.RWMutex
	clients  map[chan []message]struct{}
	buffer   []message // ring of last bufferSize messages
	latestID int64
}

func newBroadcaster(db *sql.DB, channel string) *broadcaster {
	b := &broadcaster{
		db:      db,
		channel: []byte(channel),
		clients: make(map[chan []message]struct{}),
	}
	// Seed latestID so fresh connections don't replay history.
	db.QueryRow("SELECT COALESCE(MAX(id), 0) FROM solid_cable_messages WHERE channel = ?", b.channel).Scan(&b.latestID)
	go b.run()
	return b
}

func (b *broadcaster) run() {
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()
	for range ticker.C {
		rows, err := b.db.Query(
			`SELECT id, payload FROM solid_cable_messages
			  WHERE channel = ? AND id > ?
			  ORDER BY id ASC`,
			b.channel, b.latestID,
		)
		if err != nil {
			log.Printf("broadcaster query error: %v", err)
			continue
		}

		var msgs []message
		for rows.Next() {
			var id int64
			var payload []byte
			if err := rows.Scan(&id, &payload); err != nil {
				log.Printf("scan error: %v", err)
				continue
			}
			html, err := extractTurboHTML(payload)
			if err != nil {
				log.Printf("payload parse error (id=%d): %v", id, err)
				continue
			}
			msgs = append(msgs, message{id, html})
		}
		rows.Close()

		if len(msgs) == 0 {
			continue
		}

		b.mu.Lock()
		b.buffer = append(b.buffer, msgs...)
		if len(b.buffer) > bufferSize {
			b.buffer = b.buffer[len(b.buffer)-bufferSize:]
		}
		b.latestID = msgs[len(msgs)-1].id
		for ch := range b.clients {
			select {
			case ch <- msgs:
			default: // slow client — drop; they'll catch up on reconnect via Last-Event-ID
			}
		}
		b.mu.Unlock()
	}
}

// subscribe registers a client and returns its channel plus any buffered
// messages since lastID. Subscribing under the lock closes the race window
// between catch-up and live delivery.
func (b *broadcaster) subscribe(lastID int64) (chan []message, []message) {
	b.mu.Lock()
	defer b.mu.Unlock()

	var catchup []message
	for _, m := range b.buffer {
		if m.id > lastID {
			catchup = append(catchup, m)
		}
	}

	ch := make(chan []message, 50)
	b.clients[ch] = struct{}{}
	return ch, catchup
}

func (b *broadcaster) unsubscribe(ch chan []message) {
	b.mu.Lock()
	delete(b.clients, ch)
	b.mu.Unlock()
}

// broadcasters is a registry of per-channel broadcasters.
var (
	broadcastersMu sync.Mutex
	broadcasters   = make(map[string]*broadcaster)
)

func getBroadcaster(db *sql.DB, channel string) *broadcaster {
	broadcastersMu.Lock()
	defer broadcastersMu.Unlock()
	if b, ok := broadcasters[channel]; ok {
		return b
	}
	b := newBroadcaster(db, channel)
	broadcasters[channel] = b
	return b
}

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
	mux.HandleFunc("/up", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
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

	// Fresh connection: use current max so we don't replay history Rails
	// already rendered server-side.
	// Reconnection: browser sends Last-Event-ID; we replay only missed events.
	var lastID int64
	if raw := r.Header.Get("Last-Event-ID"); raw != "" {
		if id, err := strconv.ParseInt(raw, 10, 64); err == nil {
			lastID = id
		}
	} else {
		lastID = getBroadcaster(db, channel).latestID
	}

	b := getBroadcaster(db, channel)
	ch, catchup := b.subscribe(lastID)
	defer b.unsubscribe(ch)

	log.Printf("client connected  channel=%.40s… last_id=%d", channel, lastID)

	// Send any messages missed since lastID before streaming live.
	for _, m := range catchup {
		writeSSEEvent(w, m.id, m.html)
	}
	flusher.Flush()

	for {
		select {
		case <-r.Context().Done():
			log.Printf("client disconnected last_id=%d", lastID)
			return
		case msgs := <-ch:
			for _, m := range msgs {
				writeSSEEvent(w, m.id, m.html)
				lastID = m.id
			}
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