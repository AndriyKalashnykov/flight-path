package handlers

import (
	"testing"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

// FuzzFindItinerary tests that FindItinerary never panics regardless of input.
func FuzzFindItinerary(f *testing.F) {
	// Seed corpus from existing test cases.
	f.Add("SFO", "EWR", "EWR", "ATL")
	f.Add("ATL", "EWR", "SFO", "ATL")
	f.Add("IND", "EWR", "SFO", "ATL")
	f.Add("", "", "", "")

	f.Fuzz(func(_ *testing.T, s1, d1, s2, d2 string) {
		flights := []api.Flight{
			{Start: s1, End: d1},
			{Start: s2, End: d2},
		}
		// FindItinerary must never panic regardless of input.
		FindItinerary(flights)
	})
}
