// Package main provides the entry point for the Flight Path API server.
package main

import (
	"flag"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/labstack/echo/v5"
	"github.com/labstack/echo/v5/middleware"

	_ "github.com/AndriyKalashnykov/flight-path/docs"
	"github.com/AndriyKalashnykov/flight-path/internal/handlers"
	"github.com/AndriyKalashnykov/flight-path/internal/routes"
)

// @title Flight Path API
// @version 1.0
// @description This is REST API server to determine the flight.go path of a person.
// @termsOfService http://swagger.io/terms/

// @contact.name Andriy Kalashnykov
// @contact.url https://github.com/AndriyKalashnykov/flight-path
// @contact.email AndriyKalashnykov@gmail.com

// @license.name Apache 2.0
// @license.url http://www.apache.org/licenses/LICENSE-2.0.html

// @host localhost:8080
// @BasePath /
// @schemes http.
func main() {
	// Flags
	var envFile string

	flag.StringVar(&envFile, "env-file", ".env", "File from which to load environment")
	flag.Parse()

	// Echo instance
	e := echo.New()

	// Load env vars
	err := godotenv.Load(envFile)
	if err != nil {
		log.Fatalf("failed to load environment variables: %v", err)
	}

	// Error handler — hide internal error details from responses
	e.HTTPErrorHandler = echo.DefaultHTTPErrorHandler(false)

	// Middleware
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

	// Handlers
	h := handlers.New()

	// Routes
	routes.SwaggerRoutes(e)
	routes.HealthcheckRoutes(e, &h)
	routes.FlightRoutes(e, &h)

	// Start server
	port := os.Getenv("SERVER_PORT")
	if port == "" {
		port = "8080"
	}
	if err := e.Start(":" + port); err != nil {
		log.Fatal(err)
	}
}
