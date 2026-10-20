// Package domain holds Likho's business rules and errors. It has no
// dependencies: the same rules as the Flutter app (stars, unlocks, shop),
// checked on the server so a child cannot give themselves stars.
package domain

import "errors"

// Kind says what went wrong, independent of HTTP (the API maps it to a
// status code).
type Kind int

const (
	KindInvalid         Kind = iota + 1 // bad input
	KindUnauthorized                    // sign in (again)
	KindPaymentRequired                 // needs Likho Plus
	KindNotFound                        // no such thing (or not yours)
	KindConflict                        // not allowed in the current state
	KindForbidden                       // signed in, but not allowed
	KindUnavailable                     // a service we need is not there (try later)
	KindTooMany                         // too many tries: wait, then try again
)

// Error is a business error with a stable code for the app ("level_locked")
// and a message for developers.
type Error struct {
	Kind    Kind
	Code    string
	Message string
}

func (e *Error) Error() string { return e.Code + ": " + e.Message }

// Is makes errors.Is match two errors with the same code, so a wrapped or
// copied error still matches its sentinel.
func (e *Error) Is(target error) bool {
	var t *Error
	return errors.As(target, &t) && t.Code == e.Code
}

// Invalid is a validation error about the request.
func Invalid(message string) error {
	return &Error{Kind: KindInvalid, Code: "invalid_input", Message: message}
}

var (
	ErrNotFound             = &Error{KindNotFound, "not_found", "Not found"}
	ErrCourseNotFound       = &Error{KindNotFound, "course_not_found", "No such course"}
	ErrUnknownItem          = &Error{KindNotFound, "unknown_item", "No such item in the shop"}
	ErrTooManyChildren      = &Error{KindConflict, "too_many_children", "A family can have up to 4 children"}
	ErrLastChild            = &Error{KindConflict, "last_child", "The only child profile cannot be deleted"}
	ErrLevelLocked          = &Error{KindConflict, "level_locked", "Finish the level before this one first"}
	ErrNotEnoughStars       = &Error{KindConflict, "not_enough_stars", "Not enough stars for this item"}
	ErrTrialUsed            = &Error{KindConflict, "trial_used", "The free trial was already used"}
	ErrPlusRequired         = &Error{KindPaymentRequired, "plus_required", "This level needs Likho Plus"}
	ErrTrialLimit           = &Error{KindPaymentRequired, "trial_limit", "The free trial does not open this level"}
	ErrTrialUnavailable     = &Error{KindConflict, "trial_unavailable", "There is no free trial right now"}
	ErrItemUnavailable      = &Error{KindNotFound, "item_unavailable", "This item is not in the shop right now"}
	ErrPurchaseInvalid      = &Error{KindInvalid, "purchase_invalid", "Google Play does not know this purchase"}
	ErrPurchasePending      = &Error{KindConflict, "purchase_pending", "The payment is not finished yet"}
	ErrPurchaseOtherAccount = &Error{KindConflict, "purchase_other_account", "This purchase belongs to another Likho account"}
	ErrStoreUnavailable     = &Error{KindUnavailable, "store_unavailable", "Purchases are not set up on the server"}
	ErrStoreUnreachable     = &Error{KindUnavailable, "store_unreachable", "Google Play could not be reached; try again"}
	ErrBadGoogleToken       = &Error{KindUnauthorized, "invalid_google_token", "Google sign-in could not be verified"}
	ErrSessionInvalid       = &Error{KindUnauthorized, "session_invalid", "Sign in with Google again"}
	ErrSessionReused        = &Error{KindUnauthorized, "session_reused", "Signed out on all devices for safety; sign in again"}
	ErrAccountDeleted       = &Error{KindUnauthorized, "account_deleted", "This account no longer exists"}

	// admin panel
	ErrAdminLogin     = &Error{KindUnauthorized, "invalid_login", "Wrong email or password"}
	ErrAdminSignedOut = &Error{KindUnauthorized, "signed_out", "Sign in to the admin panel"}
	ErrAdminCode      = &Error{KindUnauthorized, "invalid_code", "Wrong or expired code from the authenticator app"}
	ErrAdminTicket    = &Error{KindUnauthorized, "login_expired", "Sign in again: the code step timed out"}
	ErrAdminLocked    = &Error{KindTooMany, "login_locked", "Too many wrong tries: this account is locked for 15 minutes"}
	ErrAdminForbidden = &Error{KindForbidden, "forbidden", "Your role cannot do this"}
	ErrAdminExists    = &Error{KindConflict, "admin_exists", "An admin with this email already exists"}
	ErrLastOwner      = &Error{KindConflict, "last_owner", "The team needs at least one owner"}
	ErrContentInvalid = &Error{KindInvalid, "content_invalid", "The content has problems"}
)
