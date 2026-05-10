// Package app wires the Echo instance, middleware, and routes so main.go
// and integration tests can share a single bootstrap path.
package app

import (
	"os"
	"strings"

	"github.com/labstack/echo/v5"
	"github.com/labstack/echo/v5/middleware"

	// Imported for the init-time side effect of registering the generated
	// Swagger spec with swag's global registry — without this, GET
	// /swagger/doc.json returns 500.
	_ "github.com/AndriyKalashnykov/flight-path/docs"
	"github.com/AndriyKalashnykov/flight-path/internal/handlers"
	"github.com/AndriyKalashnykov/flight-path/internal/routes"
)

// New builds a fully-configured Echo instance with middleware and routes.
// Reads CORS_ORIGIN from the environment (defaults to "*"); a comma-separated
// list is supported for multi-origin allowlists.
func New() *echo.Echo {
	e := echo.New()

	e.HTTPErrorHandler = echo.DefaultHTTPErrorHandler(false)

	e.Use(middleware.RequestID())
	e.Use(middleware.RequestLogger())
	e.Use(middleware.Recover())
	e.Use(middleware.BodyLimit(1 << 20)) // 1 MiB
	e.Use(middleware.Gzip())

	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: parseCORSOrigins(os.Getenv("CORS_ORIGIN")),
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

func parseCORSOrigins(raw string) []string {
	if raw == "" {
		return []string{"*"}
	}
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if v := strings.TrimSpace(p); v != "" {
			out = append(out, v)
		}
	}
	if len(out) == 0 {
		return []string{"*"}
	}
	return out
}

// Port returns the server port from SERVER_PORT env var, or "8080" default.
func Port() string {
	if p := os.Getenv("SERVER_PORT"); p != "" {
		return p
	}
	return "8080"
}
