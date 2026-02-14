package routes

import (
	"github.com/AndriyKalashnykov/flight-path/internal/handlers"
	"github.com/labstack/echo/v5"
)

// HealthcheckRoutes sets up routes for the server health checks.
func HealthcheckRoutes(e *echo.Echo, h *handlers.Handler) {
	e.GET("/", h.ServerHealthCheck)
}
