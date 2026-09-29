// Package repository is the data-access layer: every database query lives
// here (through GORM). Repositories return model types and domain errors;
// they know nothing about HTTP.
package repository

import (
	"errors"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/internal/domain"
	"likho/backend/internal/model"
)

// Repositories groups one repository per area of the data.
type Repositories struct {
	Accounts *AccountRepository
	Children *ChildRepository
	Progress *ProgressRepository
	Room     *RoomRepository
	Sessions *SessionRepository
}

func New(db *gorm.DB) Repositories {
	return Repositories{
		Accounts: &AccountRepository{db: db},
		Children: &ChildRepository{db: db},
		Progress: &ProgressRepository{db: db},
		Room:     &RoomRepository{db: db},
		Sessions: &SessionRepository{db: db},
	}
}

func notFound(err error) error {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return domain.ErrNotFound
	}
	return err
}

// lockParent locks the parent row for the rest of the transaction, so
// counting and changing children cannot race.
func lockParent(tx *gorm.DB, parentID string) error {
	var p model.Parent
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Select("id").Take(&p, "id = ?", parentID).Error
	return notFound(err)
}

// lockChild loads the child (checking it belongs to the parent) and locks
// its row until the transaction ends, so two requests can never spend or
// award the same stars twice.
func lockChild(tx *gorm.DB, parentID, childID string) (model.Child, error) {
	var c model.Child
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("id = ? AND parent_id = ?", childID, parentID).
		Take(&c).Error
	return c, notFound(err)
}

func deref[T any](p *T) T {
	if p == nil {
		var z T
		return z
	}
	return *p
}
