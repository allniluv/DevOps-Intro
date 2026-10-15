package main

import (
	"encoding/json"
	"net/http"
	"time"

	spinhttp "github.com/spinframework/spin-go-sdk/v2/http"
)

type TimeResponse struct {
	Unix       int64  `json:"unix"`
	ISO        string `json:"iso"`
	HourMinute string `json:"hour_minute"`
}

func init() {
	spinhttp.Handle(func(w http.ResponseWriter, r *http.Request) {
		now := time.Now().UTC()
		moscow := now.Add(3 * time.Hour)

		response := TimeResponse{
			Unix:       now.Unix(),
			ISO:        now.Format(time.RFC3339),
			HourMinute: moscow.Format("15:04"),
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(response)
	})
}
