package main

import (
	"flag"
	"github.com/AndriyKalashnykov/flight-path/internal/handlers"
	"os"

	_ "github.com/AndriyKalashnykov/flight-path/docs"
	"github.com/AndriyKalashnykov/flight-path/internal/routes"
	"github.com/joho/godotenv"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
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
// @schemes http
func main() {

	// Flags
	var envFile string
	flag.StringVar(&envFile, "env-file", ".env", "File from which to load environment")
	flag.Parse()

	// Echo instance
	e := echo.New()
	e.HideBanner = true

	// Load env vars
	if err := godotenv.Load(envFile); err != nil {
		e.Logger.Fatalf("failed to load environment variables: %v", err)
	}

	// Middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// Handlers
	h := handlers.New()

	// Routes
	routes.SwaggerRoutes(e)
	routes.HealthcheckRoutes(e, &h)
	routes.FlightRoutes(e, &h)

	// Start server
	e.Logger.Fatal(e.Start(":" + os.Getenv("SERVER_PORT")))
}
