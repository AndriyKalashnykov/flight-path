// Package handlers contains HTTP request handlers for the flight path API.
package handlers

import (
	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

// FindItinerary finds the starting and ending airports from a list of flight segments.
// It builds sets of all start and end airports, then finds the airport that only
// appears as a start (the origin) and the airport that only appears as an end (the destination).
// Time complexity: O(n), Space complexity: O(n).
func FindItinerary(flights []api.Flight) (start, end string) {
	starts := make(map[string]bool, len(flights))
	ends := make(map[string]bool, len(flights))

	for _, f := range flights {
		starts[f.Start] = true
		ends[f.End] = true
	}

	for _, f := range flights {
		if !ends[f.Start] {
			start = f.Start
		}
		if !starts[f.End] {
			end = f.End
		}
	}

	return start, end
}
