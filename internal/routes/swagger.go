package routes

import (
	"github.com/labstack/echo/v4"
	echoSwagger "github.com/swaggo/echo-swagger"
)

// SwaggerRoutes sets up routes for the Swagger API docs.
func SwaggerRoutes(e *echo.Echo) {
	e.GET("/swagger/*", echoSwagger.WrapHandler)
}
