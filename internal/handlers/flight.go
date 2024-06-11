package handlers

import (
	"fmt"
	"github.com/AndriyKalashnykov/bfstree"
	"github.com/AndriyKalashnykov/flight-path/internal/api"
	"net/http"

	"github.com/labstack/echo/v4"
)

type TestEdge struct {
	from string
	to   string
}

// TestEdge implements bfstree.Edge interface
func (t TestEdge) To() string   { return t.to }
func (t TestEdge) From() string { return t.from }

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

	var tree *bfstree.BFSTree

	tree = bfstree.New()
	for _, t := range payload {
		tree.AddEdge(TestEdge{t[0], t[1]})
	}
	fmt.Println(tree)

	var itinerary []string
	var start, finish string
	max := -1

	for key := range api.CreateGraph(payload) {
		itinerary = api.FindItinerary(payload, key)
		fmt.Println(itinerary)
		if len(itinerary) > max {
			max = len(itinerary)
			start = itinerary[0]
			finish = itinerary[len(itinerary)-1]
		}
	}
	return c.JSON(http.StatusOK, []string{start, finish})

}
