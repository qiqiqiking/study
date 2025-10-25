package conf

import (
	"fmt"
	"log"
	"os"

	"github.com/BurntSushi/toml"
)

type MySQLConfig struct {
	Host     string `toml:"host"`
	Port     int    `toml:"port"`
	User     string `toml:"user"`
	Password string `toml:"password"`
	Database string `toml:"database"`
	Charset  string `toml:"charset"`
}

type Config struct {
	MySQL MySQLConfig `toml:"mysql"`
}

// LoadConfig 从文件加载配置，默认 config.toml
func LoadConfig(path string) *Config {
	if path == "" {
		path = "config.toml"
	}

	if _, err := os.Stat(path); os.IsNotExist(err) {
		log.Fatalf("❌ Config file not found: %s", path)
	}

	var cfg Config
	_, err := toml.DecodeFile(path, &cfg)
	if err != nil {
		log.Fatalf("❌ Failed to parse config file: %v", err)
	}

	return &cfg
}

// DSN 生成 MySQL 连接字符串
func (m *MySQLConfig) DSN() string {
	return m.User + ":" + m.Password + "@tcp(" + m.Host + ":" +
		fmt.Sprint(m.Port) + ")/" + m.Database +
		"?charset=" + m.Charset + "&parseTime=True&loc=Local"
}
