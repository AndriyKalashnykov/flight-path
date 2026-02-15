package handlers

import (
	"net/http"
	"sync"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
	"github.com/labstack/echo/v5"
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
// @Failure 400 {object} map[string]interface{}	"Bad Request"
// @Failure 500 {object} map[string]interface{}	"Internal Server Error"
// @Router /calculate [post].
func (h Handler) FlightCalculate(c *echo.Context) error {
	var payload [][]string

	// bind payload
	err := c.Bind(&payload)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]any{
			"Error": "Can't parse the payload",
		})
	}

	// validate payload
	if len(payload) == 0 {
		return c.JSON(http.StatusBadRequest, map[string]any{
			"Error": "Flight segments cannot be empty",
		})
	}

	flights := make([]api.Flight, 0, len(payload))
	for i, v := range payload {
		if len(v) < 2 {
			return c.JSON(http.StatusBadRequest, map[string]any{
				"Error": "Each flight segment must contain both source and destination",
				"Index": i,
			})
		}
		flights = append(flights, api.Flight{
			Start: v[0],
			End:   v[1],
		})
	}

	start, finish := FindItinerary2(flights, &sync.Map{}, &sync.Map{})

	return c.JSON(http.StatusOK, []string{start, finish})
}
