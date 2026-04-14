// Package app wires the Echo instance, middleware, and routes so main.go
// and integration tests can share a single bootstrap path.
package app

import (
	"os"

	"github.com/labstack/echo/v5"
	"github.com/labstack/echo/v5/middleware"

	"github.com/AndriyKalashnykov/flight-path/internal/handlers"
	"github.com/AndriyKalashnykov/flight-path/internal/routes"
)

// New builds a fully-configured Echo instance with middleware and routes.
// Reads CORS_ORIGIN from the environment (defaults to "*").
func New() *echo.Echo {
	e := echo.New()

	e.HTTPErrorHandler = echo.DefaultHTTPErrorHandler(false)

	e.Use(middleware.RequestLogger())
	e.Use(middleware.Recover())

	corsOrigin := os.Getenv("CORS_ORIGIN")
	if corsOrigin == "" {
		corsOrigin = "*"
	}
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{corsOrigin},
	}))
	e.Use(middleware.SecureWithConfig(middleware.SecureConfig{
		XSSProtection:      "1; mode=block",
		ContentTypeNosniff: "nosniff",
		XFrameOptions:      "DENY",
		ReferrerPolicy:     "strict-origin-when-cross-origin",
	}))
	e.Use(func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c *echo.Context) error {
			c.Response().Header().Set("Cross-Origin-Resource-Policy", "same-origin")
			c.Response().Header().Set("Cache-Control", "no-store")
			return next(c)
		}
	})

	h := handlers.New()
	routes.SwaggerRoutes(e)
	routes.HealthcheckRoutes(e, &h)
	routes.FlightRoutes(e, &h)

	return e
}

// Port returns the server port from SERVER_PORT env var, or "8080" default.
func Port() string {
	if p := os.Getenv("SERVER_PORT"); p != "" {
		return p
	}
	return "8080"
}
