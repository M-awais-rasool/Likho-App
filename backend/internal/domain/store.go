package domain

import (
	"crypto/sha256"
	"encoding/hex"
)

// StoreAccountID is the account's ID as Google Play sees it (the
// obfuscatedAccountId the app sends with a purchase): a one-way hash, so
// no Likho account ID leaves Likho, but the server can tell whose a
// purchase is.
func StoreAccountID(parentID string) string {
	h := sha256.Sum256([]byte("likho:" + parentID))
	return hex.EncodeToString(h[:])
}
