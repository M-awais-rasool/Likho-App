// Command api runs the Likho API (Go + Gin + Postgres/GORM + Redis).
//
//	go run ./cmd/api          (settings from the environment, see .env.example)
//	likho-api health          exit 0 when the API on $PORT is ready (Docker's
//	                          health check: the image has no shell or curl)
//	likho-api admin-reset-2fa <email>
//	                          a lost phone: the admin sets up the authenticator
//	                          app again at the next sign-in (on the server:
//	                          docker compose exec api /likho-api admin-reset-2fa …)
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"likho/backend/internal/app"
	"likho/backend/internal/config"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "health" {
		os.Exit(health())
	}
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	cfg, err := config.Load()
	if err != nil {
		slog.Error("config", "err", err)
		os.Exit(1)
	}
	if len(os.Args) > 1 && os.Args[1] == "admin-reset-2fa" {
		if len(os.Args) != 3 {
			fmt.Fprintln(os.Stderr, "usage: likho-api admin-reset-2fa <email>")
			os.Exit(2)
		}
		if err := app.ResetAdminTwoFactor(context.Background(), cfg, os.Args[2]); err != nil {
			slog.Error("admin-reset-2fa", "err", err)
			os.Exit(1)
		}
		fmt.Println("two-step sign-in reset for", os.Args[2], "- set up the authenticator app at the next sign-in")
		return
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := app.Run(ctx, cfg); err != nil {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

func health() int {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	client := http.Client{Timeout: 3 * time.Second}
	res, err := client.Get("http://127.0.0.1:" + port + "/readyz")
	if err != nil {
		return 1
	}
	_ = res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
