package main

import (
	_ "github.com/AndriyKalashnykov/flight-path/docs"
	"github.com/AndriyKalashnykov/flight-path/internal/routes"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	echoSwagger "github.com/swaggo/echo-swagger"
)

// @title Flight Path API
// @version 1.0
// @description This is REST API server to determine the flight path of a person.
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
	// Echo instance
	e := echo.New()

	// Middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// Routes
	e.GET("/", routes.HealthCheck)
	e.GET("/swagger/*", echoSwagger.WrapHandler)

	// Start server
	e.Logger.Fatal(e.Start(":8080"))
}
