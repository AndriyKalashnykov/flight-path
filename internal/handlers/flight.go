package handlers

import (
	"net/http"

	"github.com/labstack/echo/v5"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

// errorKey is the JSON field name for error messages in 400/500 responses.
const errorKey = "Error"

// indexKey is the JSON field naming the offending segment's index in
// per-segment validation errors.
const indexKey = "Index"

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
		return c.JSON(http.StatusBadRequest, map[string]any{
			errorKey: "Can't parse the payload",
		})
	}

	// validate payload
	if len(payload) == 0 {
		return c.JSON(http.StatusBadRequest, map[string]any{
			errorKey: "Flight segments cannot be empty",
		})
	}

	flights := make([]api.Flight, 0, len(payload))
	for i, v := range payload {
		if len(v) < 2 {
			return c.JSON(http.StatusBadRequest, map[string]any{
				errorKey: "Each flight segment must contain both source and destination",
				indexKey: i,
			})
		}
		src, dst := v[0], v[1]
		if src == "" || dst == "" {
			return c.JSON(http.StatusBadRequest, map[string]any{
				errorKey: "Airport codes must be non-empty",
				indexKey: i,
			})
		}
		if src == dst {
			return c.JSON(http.StatusBadRequest, map[string]any{
				errorKey: "Source and destination airports must differ",
				indexKey: i,
			})
		}
		flights = append(flights, api.Flight{
			Start: src,
			End:   dst,
		})
	}

	start, finish, err := FindItinerary(flights)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{
			errorKey: err.Error(),
		})
	}

	return c.JSON(http.StatusOK, []string{start, finish})
}
