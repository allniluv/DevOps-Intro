package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"
)

type TimeResponse struct {
	Unix       int64  `json:"unix"`
	ISO        string `json:"iso"`
	HourMinute string `json:"hour_minute"`
}

func main() {
	method := os.Getenv("REQUEST_METHOD")
	path := os.Getenv("PATH_INFO")

	if method != "GET" || path != "/time" {
		fmt.Println("Status: 404 Not Found")
		fmt.Println("Content-Type: application/json")
		fmt.Println()
		fmt.Println(`{"error":"not found"}`)
		return
	}

	now := time.Now().UTC()
	moscow := now.Add(3 * time.Hour)

	response := TimeResponse{
		Unix:       now.Unix(),
		ISO:        now.Format(time.RFC3339),
		HourMinute: moscow.Format("15:04"),
	}

	body, _ := json.Marshal(response)

	fmt.Println("Status: 200 OK")
	fmt.Println("Content-Type: application/json")
	fmt.Println()
	fmt.Println(string(body))
}
