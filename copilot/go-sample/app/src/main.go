package main

import (
	"github.com/gin-gonic/gin"
	"local.packages/domains"
)

func main() {
	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		domains.FooSample()
		c.JSON(200, gin.H{
			"message": "pong",
		})
	})
	r.Run(":8080") // listen and serve on 0.0.0.0:8080 (for windows "localhost:8080")
}
