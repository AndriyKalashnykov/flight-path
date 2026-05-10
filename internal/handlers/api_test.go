package handlers

import (
	"errors"
	"testing"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

func TestFindItinerary(t *testing.T) {
	tests := []struct {
		name      string
		flights   []api.Flight
		wantStart string
		wantEnd   string
		wantErr   error
	}{
		{
			name:      "empty input",
			flights:   []api.Flight{},
			wantStart: "",
			wantEnd:   "",
			wantErr:   nil,
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
		{
			name: "circular path A-B-A is rejected",
			flights: []api.Flight{
				{Start: "A", End: "B"},
				{Start: "B", End: "A"},
			},
			wantErr: ErrCircularPath,
		},
		{
			name: "disconnected pairs are rejected",
			flights: []api.Flight{
				{Start: "A", End: "B"},
				{Start: "C", End: "D"},
			},
			wantErr: ErrDisconnectedGraph,
		},
		{
			name: "two segments sharing a source are rejected (ambiguous start)",
			flights: []api.Flight{
				{Start: "A", End: "B"},
				{Start: "A", End: "C"},
			},
			wantErr: ErrDisconnectedGraph,
		},
		{
			name: "two segments sharing a destination are rejected (ambiguous end)",
			flights: []api.Flight{
				{Start: "A", End: "C"},
				{Start: "B", End: "C"},
			},
			wantErr: ErrDisconnectedGraph,
		},
		{
			name: "duplicate segment behaves as a single segment",
			flights: []api.Flight{
				{Start: "A", End: "B"},
				{Start: "A", End: "B"},
			},
			wantStart: "A",
			wantEnd:   "B",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotStart, gotEnd, err := FindItinerary(tt.flights)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("FindItinerary() err = %v, want %v", err, tt.wantErr)
			}
			if tt.wantErr != nil {
				return
			}
			if gotStart != tt.wantStart {
				t.Errorf("FindItinerary() start = %q, want %q", gotStart, tt.wantStart)
			}
			if gotEnd != tt.wantEnd {
				t.Errorf("FindItinerary() end = %q, want %q", gotEnd, tt.wantEnd)
			}
		})
	}
}
