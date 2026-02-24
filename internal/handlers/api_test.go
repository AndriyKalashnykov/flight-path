package handlers

import (
	"testing"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

func TestFindItinerary(t *testing.T) {
	tests := []struct {
		name      string
		flights   []api.Flight
		wantStart string
		wantEnd   string
	}{
		{
			name:      "empty input",
			flights:   []api.Flight{},
			wantStart: "",
			wantEnd:   "",
		},
		{
			name: "single flight",
			flights: []api.Flight{
				{Start: "SFO", End: "EWR"},
			},
			wantStart: "SFO",
			wantEnd:   "EWR",
		},
		{
			name: "two flights in order",
			flights: []api.Flight{
				{Start: "SFO", End: "ATL"},
				{Start: "ATL", End: "EWR"},
			},
			wantStart: "SFO",
			wantEnd:   "EWR",
		},
		{
			name: "two flights reversed",
			flights: []api.Flight{
				{Start: "ATL", End: "EWR"},
				{Start: "SFO", End: "ATL"},
			},
			wantStart: "SFO",
			wantEnd:   "EWR",
		},
		{
			name: "four flights shuffled",
			flights: []api.Flight{
				{Start: "IND", End: "EWR"},
				{Start: "SFO", End: "ATL"},
				{Start: "GSO", End: "IND"},
				{Start: "ATL", End: "GSO"},
			},
			wantStart: "SFO",
			wantEnd:   "EWR",
		},
		{
			name:      "TestFlights fixture 19 segments BGY to AKL",
			flights:   api.TestFlights,
			wantStart: "BGY",
			wantEnd:   "AKL",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotStart, gotEnd := FindItinerary(tt.flights)
			if gotStart != tt.wantStart {
				t.Errorf("FindItinerary() start = %q, want %q", gotStart, tt.wantStart)
			}
			if gotEnd != tt.wantEnd {
				t.Errorf("FindItinerary() end = %q, want %q", gotEnd, tt.wantEnd)
			}
		})
	}
}
