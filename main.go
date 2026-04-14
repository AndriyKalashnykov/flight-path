// Package main provides the entry point for the Flight Path API server.
package main

import (
	"flag"
	"log"

	"github.com/joho/godotenv"

	_ "github.com/AndriyKalashnykov/flight-path/docs"
	"github.com/AndriyKalashnykov/flight-path/internal/app"
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
	var envFile string
	flag.StringVar(&envFile, "env-file", ".env", "File from which to load environment")
	flag.Parse()

	if err := godotenv.Load(envFile); err != nil {
		log.Fatalf("failed to load environment variables: %v", err)
	}

	e := app.New()
	if err := e.Start(":" + app.Port()); err != nil {
		log.Fatal(err)
	}
}
