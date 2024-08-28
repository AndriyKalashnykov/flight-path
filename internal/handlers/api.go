package handlers

import (
	"github.com/AndriyKalashnykov/flight-path/pkg/api"
	"sort"
	"sync"
)

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

func CreateGraph(segments [][]string) map[string][]string {
	g := map[string][]string{}
	for _, t := range segments {
		g[t[0]] = append(g[t[0]], t[1])
	}
	return g
}

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

func FindItinerary2(flights []api.Flight, s, e *sync.Map) (string, string) {
	start := make(chan string, 1)
	end := make(chan string, 1)
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
				start <- v.Start
			}
			if _, ok := e.Load(v.End); !ok {
				end <- v.End
			}
		}(v)
	}

	go func(st, en chan string) {
		wg.Wait()
		close(st)
		close(en)
	}(start, end)

	return <-start, <-end
}
