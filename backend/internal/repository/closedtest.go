package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"likho/backend/internal/domain"
	"likho/backend/internal/model"
)

// ClosedTestRepository: the Google Play closed test (testers, whose
// account is whose, and the days each account used the app).
type ClosedTestRepository struct {
	db *gorm.DB
}

// AddDay records that the account used the app on [day]; true the first
// time that day.
func (r *ClosedTestRepository) AddDay(ctx context.Context, parentID string, day time.Time) (bool, error) {
	res := r.db.WithContext(ctx).Clauses(clause.OnConflict{DoNothing: true}).Create(&model.ClosedTestDay{ParentID: parentID, Day: day})
	return res.RowsAffected == 1, res.Error
}

// Days returns every recorded day, oldest first.
func (r *ClosedTestRepository) Days(ctx context.Context) ([]model.ClosedTestDay, error) {
	var out []model.ClosedTestDay
	err := r.db.WithContext(ctx).Order("day, parent_id").Find(&out).Error
	return out, err
}

// Link returns whose the account is (found = false: nobody said yet).
func (r *ClosedTestRepository) Link(ctx context.Context, parentID string) (a model.ClosedTestAccount, found bool, err error) {
	err = r.db.WithContext(ctx).Take(&a, "parent_id = ?", parentID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return a, false, nil
	}
	return a, err == nil, err
}

// SetLink makes the account [testerID]'s (nil: not a tester).
func (r *ClosedTestRepository) SetLink(ctx context.Context, parentID string, testerID *string, auto bool) error {
	err := r.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "parent_id"}},
		DoUpdates: clause.AssignmentColumns([]string{"tester_id", "auto", "linked_at"}),
	}).Create(&model.ClosedTestAccount{ParentID: parentID, TesterID: testerID, Auto: auto, LinkedAt: time.Now()}).Error
	if errors.Is(err, gorm.ErrForeignKeyViolated) {
		return domain.ErrNotFound
	}
	return err
}

// Unlink forgets whose the account is (it is listed as new again).
func (r *ClosedTestRepository) Unlink(ctx context.Context, parentID string) error {
	return r.db.WithContext(ctx).Delete(&model.ClosedTestAccount{}, "parent_id = ?", parentID).Error
}

// GivePerks gives the account Likho Plus until [plusUntil] (when it ends
// sooner; nil = no Plus) and opens every level ([openLevels]). True when
// anything changed.
func (r *ClosedTestRepository) GivePerks(ctx context.Context, parentID string, plusUntil *time.Time, openLevels bool) (bool, error) {
	changed := false
	db := r.db.WithContext(ctx).Model(&model.Parent{})
	if plusUntil != nil {
		res := db.Where("id = ? AND (plus_until IS NULL OR plus_until < ?)", parentID, *plusUntil).Update("plus_until", *plusUntil)
		if res.Error != nil {
			return false, res.Error
		}
		changed = res.RowsAffected > 0
	}
	if openLevels {
		res := r.db.WithContext(ctx).Model(&model.Parent{}).Where("id = ? AND NOT tester", parentID).Update("tester", true)
		if res.Error != nil {
			return changed, res.Error
		}
		changed = changed || res.RowsAffected > 0
	}
	return changed, nil
}

// TesterAccounts returns the accounts treated as testers: linked to one,
// or seen in the test with nobody saying whose they are yet (not the ones
// marked as not a tester).
func (r *ClosedTestRepository) TesterAccounts(ctx context.Context) ([]string, error) {
	var ids []string
	err := r.db.WithContext(ctx).Raw(`
		SELECT parent_id FROM closed_test_accounts WHERE tester_id IS NOT NULL
		UNION
		SELECT DISTINCT d.parent_id FROM closed_test_days d
		WHERE NOT EXISTS (SELECT 1 FROM closed_test_accounts a WHERE a.parent_id = d.parent_id)`).Scan(&ids).Error
	return ids, err
}

// SetOpenLevels opens (or closes) every level for the accounts [ids];
// returns the ones that changed.
func (r *ClosedTestRepository) SetOpenLevels(ctx context.Context, ids []string, open bool) ([]string, error) {
	var changed []string
	if len(ids) == 0 {
		return changed, nil
	}
	err := r.db.WithContext(ctx).Raw(`UPDATE parents SET tester = ? WHERE tester <> ? AND id IN ? RETURNING id`, open, open, ids).Scan(&changed).Error
	return changed, err
}

// ---------------------------------------------------------------- testers

func (r *ClosedTestRepository) Testers(ctx context.Context) ([]model.ClosedTester, error) {
	var out []model.ClosedTester
	err := r.db.WithContext(ctx).Order("created_at, name").Find(&out).Error
	return out, err
}

func (r *ClosedTestRepository) Tester(ctx context.Context, id string) (model.ClosedTester, error) {
	var t model.ClosedTester
	err := r.db.WithContext(ctx).Take(&t, "id = ?", id).Error
	return t, notFound(err)
}

func (r *ClosedTestRepository) CreateTesters(ctx context.Context, ts []model.ClosedTester) error {
	if len(ts) == 0 {
		return nil
	}
	return r.db.WithContext(ctx).Create(&ts).Error
}

func (r *ClosedTestRepository) UpdateTester(ctx context.Context, id string, updates map[string]any) (model.ClosedTester, error) {
	var t model.ClosedTester
	res := r.db.WithContext(ctx).Model(&t).Clauses(clause.Returning{}).Where("id = ?", id).Updates(updates)
	if res.Error == nil && res.RowsAffected == 0 {
		return t, domain.ErrNotFound
	}
	return t, res.Error
}

// DeleteTester removes the tester; their accounts are listed as new again.
func (r *ClosedTestRepository) DeleteTester(ctx context.Context, id string) error {
	res := r.db.WithContext(ctx).Delete(&model.ClosedTester{}, "id = ?", id)
	if res.Error == nil && res.RowsAffected == 0 {
		return domain.ErrNotFound
	}
	return res.Error
}

// TestAccountRow is an account seen in the closed test, with whose it is.
type TestAccountRow struct {
	ParentID   string     `json:"parentId"`
	Email      string     `json:"email"`
	Name       string     `json:"name"`
	PictureURL string     `json:"pictureUrl"`
	Platform   string     `json:"platform"`
	AppVersion string     `json:"appVersion"`
	Country    string     `json:"country"`
	CreatedAt  time.Time  `json:"createdAt"`
	LastSeenAt *time.Time `json:"lastSeenAt"`
	PlusUntil  *time.Time `json:"plusUntil"`
	OpenLevels bool       `json:"openLevels"`
	Children   int        `json:"children"`
	Levels     int        `json:"levels"` // levels finished by its children
	Linked     bool       `json:"-"`      // someone said whose it is
	TesterID   *string    `json:"testerId"`
	Auto       bool       `json:"auto"`
	Days       []string   `json:"days" gorm:"-"`
}

// Accounts returns the accounts that used the app during the test or were
// linked, oldest first.
func (r *ClosedTestRepository) Accounts(ctx context.Context) ([]TestAccountRow, error) {
	var out []TestAccountRow
	err := r.db.WithContext(ctx).Raw(`
		SELECT p.id AS parent_id, p.email, p.name, p.picture_url, p.platform, p.app_version, p.country,
		  p.created_at, p.last_seen_at, p.plus_until, p.tester AS open_levels,
		  (SELECT count(*) FROM children c WHERE c.parent_id = p.id) AS children,
		  (SELECT count(*) FROM level_progress lp JOIN children c ON c.id = lp.child_id WHERE c.parent_id = p.id) AS levels,
		  a.parent_id IS NOT NULL AS linked, a.tester_id, COALESCE(a.auto, false) AS auto
		FROM parents p LEFT JOIN closed_test_accounts a ON a.parent_id = p.id
		WHERE a.parent_id IS NOT NULL OR EXISTS (SELECT 1 FROM closed_test_days d WHERE d.parent_id = p.id)
		ORDER BY p.created_at`).Scan(&out).Error
	return out, err
}
