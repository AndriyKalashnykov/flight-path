// Package handlers contains HTTP request handlers for the flight path API.
package handlers

import (
	"errors"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

// Sentinel errors for FindItinerary contract violations. Handlers map these
// to HTTP 400 responses.
var (
	// ErrCircularPath is returned when every airport is both a source and a
	// destination, leaving no unambiguous start or end.
	ErrCircularPath = errors.New("circular path: every airport is both a source and a destination")

	// ErrDisconnectedGraph is returned when more than one airport has no
	// incoming edge or no outgoing edge — i.e., the input describes multiple
	// distinct itineraries instead of a single connected path.
	ErrDisconnectedGraph = errors.New("disconnected graph: multiple distinct itineraries detected")
)

// FindItinerary determines the starting and ending airports for a single
// connected itinerary represented by an unordered slice of flight segments.
// It builds the in-degree and out-degree sets, identifies the unique source
// (no incoming edge) and unique destination (no outgoing edge), and rejects
// inputs that don't fit that shape via ErrCircularPath / ErrDisconnectedGraph.
// Empty input returns ("", "", nil) — the caller is expected to reject empty
// payloads before calling this function.
// Time complexity: O(n), space complexity: O(n).
func FindItinerary(flights []api.Flight) (start, end string, err error) {
	if len(flights) == 0 {
		return "", "", nil
	}

	starts := make(map[string]bool, len(flights))
	ends := make(map[string]bool, len(flights))
	for _, f := range flights {
		starts[f.Start] = true
		ends[f.End] = true
	}

	startCandidates := make([]string, 0, 1)
	endCandidates := make([]string, 0, 1)
	for s := range starts {
		if !ends[s] {
			startCandidates = append(startCandidates, s)
		}
	}
	for e := range ends {
		if !starts[e] {
			endCandidates = append(endCandidates, e)
		}
	}

	if len(startCandidates) == 0 || len(endCandidates) == 0 {
		return "", "", ErrCircularPath
	}
	if len(startCandidates) > 1 || len(endCandidates) > 1 {
		return "", "", ErrDisconnectedGraph
	}
	return startCandidates[0], endCandidates[0], nil
}
