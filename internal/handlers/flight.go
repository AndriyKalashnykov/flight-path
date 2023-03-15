package handlers

import (
	"fmt"
	"net/http"
	"sort"

	"github.com/labstack/echo/v4"
)

// FlightCalculate godoc
// @Summary Determine the flight path of a person.
// @Description get the flight path of a person.
// @Tags FlightCalculate
// @ID flightCalculate-get
// @Accept json
// @Produce json
// @Param   flightSegments	body	[][]string	true	"Flight segments"
// @Success 200 {object} []string
// @Failure 500 {object} map[string]interface{}	"Internal Server Error"
// @Router /calculate [post]
func (h Handler) FlightCalculate(c echo.Context) error {
	var payload [][]string

	// bind payload
	if err := c.Bind(&payload); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"Error": "Cant' parse the payload",
		})
	}

	var itinerary []string
	var start, finish string
	max := -1

	for key, _ := range CreateGraph(payload) {
		itinerary = FindItinerary(payload, key)
		fmt.Println(itinerary)
		if len(itinerary) > max {
			max = len(itinerary)
			start = itinerary[0]
			finish = itinerary[len(itinerary)-1]
		}
	}

	return c.JSON(http.StatusOK, []string{start, finish})
}

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
