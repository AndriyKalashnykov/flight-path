package handlers

import (
	"net/http"

	"github.com/labstack/echo/v4"
)

// ServerHealthCheck godoc
// @Summary Show the status of server.
// @Description get the status of server.
// @Tags ServerHealthCheck
// @ID healthCheck-get
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router / [get].
func (h Handler) ServerHealthCheck(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]any{
		"data": "Server is up and running",
	})
}
