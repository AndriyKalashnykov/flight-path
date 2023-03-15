package api

import "sort"

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
