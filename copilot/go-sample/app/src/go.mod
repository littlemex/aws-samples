module main

go 1.14

require (
	github.com/gin-gonic/gin v1.6.3
	github.com/jinzhu/gorm v1.9.15 // indirect
	local.packages/domains v0.0.0-00010101000000-000000000000
	local.packages/models v0.0.0-00010101000000-000000000000 // indirect
)

replace local.packages/domains => ./domains

replace local.packages/models => ./models

