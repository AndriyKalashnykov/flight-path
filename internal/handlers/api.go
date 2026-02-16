// Package handlers contains HTTP request handlers for the flight path API.
package handlers

import (
	"sync"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

// FindItinerary finds the starting and ending airports using concurrent processing.
func FindItinerary(flights []api.Flight, s, e *sync.Map) (start, end string) {
	wg := sync.WaitGroup{}

	for _, v := range flights {
		wg.Add(1)

		go func(v api.Flight) {
			defer wg.Done()

			for _, w := range flights {
				if v.Start == w.End {
					s.Store(v.Start, true)
				}

				if v.End == w.Start {
					e.Store(v.End, true)
				}
			}
		}(v)
	}

	wg.Wait()

	// After all goroutines complete, find start and end with no races
	for _, v := range flights {
		if _, ok := s.Load(v.Start); !ok && start == "" {
			start = v.Start
		}

		if _, ok := e.Load(v.End); !ok && end == "" {
			end = v.End
		}
	}

	return start, end
}
