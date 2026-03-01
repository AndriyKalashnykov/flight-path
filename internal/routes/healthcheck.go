package routes

import (
	"github.com/labstack/echo/v5"

	"github.com/AndriyKalashnykov/flight-path/internal/handlers"
)

// HealthcheckRoutes sets up routes for the server health checks.
func HealthcheckRoutes(e *echo.Echo, h *handlers.Handler) {
	e.GET("/", h.ServerHealthCheck)
}
