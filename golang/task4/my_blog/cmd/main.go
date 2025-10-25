package main

import (
	"github.com/gin-gonic/gin"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"log"

	"my_blog/internal/conf"
	"my_blog/internal/model"
	"my_blog/internal/route" // 👈 确保导入了 route 包
)

var db *gorm.DB

func init() {
	// 优先从环境变量读取配置文件路径，否则用默认 config.toml
	configPath := "conf/mysql.toml"
	cfg := conf.LoadConfig(configPath)

	dsn := cfg.MySQL.DSN()
	var err error
	db, err = gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("❌ Failed to connect to MySQL:", err)
	}
	db.AutoMigrate(&model.User{}, &model.Post{}, &model.Comment{})
	log.Println("✅ Connected to MySQL using config.toml")
}

func main() {
	r := gin.Default()
	if err := r.SetTrustedProxies([]string{
		"127.0.0.1",
		"::1",
		"10.0.0.0/8",
		"172.16.0.0/12",
		"192.168.0.0/16",
	}); err != nil {
		log.Fatalf("Failed to set trusted proxies: %v", err)
	}

	route.RegisterRoutes(r, db)

	log.Println("🚀 Server running on :8080")
	r.Run(":8080")
}
