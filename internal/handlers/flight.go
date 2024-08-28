package handlers

import (
	"github.com/AndriyKalashnykov/flight-path/pkg/api"
	"net/http"
	"sync"

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

	//var itinerary []string
	//var start, finish string
	//max := -1
	//
	//for key := range api.CreateGraph(payload) {
	//	itinerary = api.FindItinerary(payload, key)
	//	fmt.Println(itinerary)
	//	if len(itinerary) > max {
	//		max = len(itinerary)
	//		start = itinerary[0]
	//		finish = itinerary[len(itinerary)-1]
	//	}
	//}

	flights := make([]api.Flight, 0, len(payload))
	for _, v := range payload {
		flights = append(flights, api.Flight{v[0], v[1]})
	}

	start, finish := FindItinerary2(flights, &sync.Map{}, &sync.Map{})

	return c.JSON(http.StatusOK, []string{start, finish})

}
