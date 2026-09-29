// Package repository is the only place that talks to the database (through
// GORM). Handlers never build queries; the store never knows about HTTP.
package repository

import (
	"errors"

	"gorm.io/gorm"
)

type Store struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Store { return &Store{db: db} }

// Errors the handlers turn into HTTP answers.
var (
	ErrNotFound        = errors.New("not found")
	ErrTooManyChildren = errors.New("too many children")
	ErrLastChild       = errors.New("cannot delete the only child")
	ErrLevelLocked     = errors.New("level is locked")
	ErrPlusRequired    = errors.New("likho plus required")
	ErrNotEnoughStars  = errors.New("not enough stars")
	ErrUnknownItem     = errors.New("unknown shop item")
	ErrTrialUsed       = errors.New("trial already used")
	ErrSessionInvalid  = errors.New("session invalid")
	ErrSessionReused   = errors.New("refresh token reused")
)

func notFound(err error) error {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrNotFound
	}
	return err
}
