package domains

import (
	"os"

	"local.packages/models"

	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/postgres"
)

func FooSample() {
	host := os.Getenv("DB_HOST")
	user := os.Getenv("DB_USER")
	password := os.Getenv("DB_PASSWORD")
	dbname := os.Getenv("DB_NAME")
	db, err := gorm.Open("postgres", "host="+host+" user="+user+" password="+password+" dbname="+dbname+" sslmode=disable")
	if err != nil {
		panic(err.Error())
	}
	defer db.Close()

	// スキーマのマイグレーション
	var models models.Model
	db.AutoMigrate(&models)

	// Create
	//db.Create(&models{Code: "L1212", Price: 1000})

	db.First(&models, 1)
	//fmt.Printf("model %#v\n", &models.id)
}
