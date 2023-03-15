package routes

import (
	"github.com/AndriyKalashnykov/flight-path/internal/handlers"
	"github.com/labstack/echo/v4"
)

// FlightRoutes sets up routes for the flight calculations.
func FlightRoutes(e *echo.Echo, h *handlers.Handler) {
	e.POST("/calculate", h.FlightCalculate)
}
