// Package handlers contains HTTP request handlers for the flight path API.
package handlers

import (
	"sort"
	"sync"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

// FindItinerary determines the complete flight itinerary starting from a given airport.
func FindItinerary(segments [][]string, start string) []string {
	sort.Slice(segments, func(i, j int) bool {
		if segments[i][0] < segments[j][0] {
			return true
		}

		if segments[i][0] > segments[j][0] {
			return false
		}

		return segments[i][1] < segments[j][1]
	})

	g := CreateGraph(segments)

	var flightSegments []string

	DFS(g, start, &flightSegments)

	return flightSegments
}

// CreateGraph builds an adjacency list graph from flight segments.
func CreateGraph(segments [][]string) map[string][]string {
	g := map[string][]string{}
	for _, t := range segments {
		g[t[0]] = append(g[t[0]], t[1])
	}

	return g
}

// DFS performs depth-first search to build the flight path.
func DFS(g map[string][]string, start string, flightSegments *[]string) {
	for {
		dest, exists := g[start]

		if exists && len(dest) > 0 {
			first := g[start][0]
			g[start] = g[start][1:]

			DFS(g, first, flightSegments)
		} else {
			break
		}
	}

	*flightSegments = append([]string{start}, *flightSegments...)
}

// FindItinerary2 finds the starting and ending airports using concurrent processing.
func FindItinerary2(flights []api.Flight, s, e *sync.Map) (start, end string) {
	startChan := make(chan string, 1)
	endChan := make(chan string, 1)
	wg := sync.WaitGroup{}

	for _, v := range flights {
		wg.Add(1)

		go func(v api.Flight) {
			defer wg.Done()

			for _, w := range flights {
				_, nSFound := s.Load(v.Start)
				_, nEFound := e.Load(v.End)

				if !nSFound && v.Start == w.End {
					s.Store(v.Start, true)
				}

				if !nEFound && v.End == w.Start {
					e.Store(v.End, true)
				}
			}

			if _, ok := s.Load(v.Start); !ok {
				startChan <- v.Start
			}

			if _, ok := e.Load(v.End); !ok {
				endChan <- v.End
			}
		}(v)
	}

	go func(st, en chan string) {
		wg.Wait()
		close(st)
		close(en)
	}(startChan, endChan)

	return <-startChan, <-endChan
}
