package service

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"crypto/subtle"
	"encoding/base32"
	"encoding/binary"
	"fmt"
	"net/url"
	"strings"
	"time"
)

// Time-based one-time codes (RFC 6238: HMAC-SHA1, 6 digits, 30 s), the
// codes of Google Authenticator, Microsoft Authenticator, 1Password and
// others: the admin panel's second sign-in step.

const (
	totpPeriod = 30
	totpDigits = 6
	totpIssuer = "Likho Admin"
)

var totpBase32 = base32.StdEncoding.WithPadding(base32.NoPadding)

// NewTOTPSecret is a random 160-bit secret in base32 (what the apps take).
func NewTOTPSecret() (string, error) {
	b := make([]byte, 20)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return totpBase32.EncodeToString(b), nil
}

// TOTPURL is the otpauth:// link the panel shows as a QR code.
func TOTPURL(secret, account string) string {
	label := url.PathEscape(totpIssuer + ":" + account)
	q := url.Values{"secret": {secret}, "issuer": {totpIssuer}, "algorithm": {"SHA1"}, "digits": {"6"}, "period": {"30"}}
	return "otpauth://totp/" + label + "?" + q.Encode()
}

func totpStep(t time.Time) int64 { return t.Unix() / totpPeriod }

// TOTPCode is the code for [secret] at [t] (tests sign in with it).
func TOTPCode(secret string, t time.Time) (string, error) {
	return totpAt(secret, totpStep(t))
}

func totpAt(secret string, step int64) (string, error) {
	key, err := totpBase32.DecodeString(strings.ToUpper(strings.TrimRight(secret, "=")))
	if err != nil {
		return "", err
	}
	var msg [8]byte
	binary.BigEndian.PutUint64(msg[:], uint64(step))
	m := hmac.New(sha1.New, key)
	m.Write(msg[:])
	sum := m.Sum(nil)
	off := sum[len(sum)-1] & 0x0f
	n := binary.BigEndian.Uint32(sum[off:off+4]) & 0x7fffffff
	return fmt.Sprintf("%06d", n%1_000_000), nil
}

// checkTOTP finds the step [code] belongs to: now or one step either side
// (a phone clock a little off, a code typed as it changed), and only
// steps after [last] (a code works once). ok = false for anything else.
func checkTOTP(secret, code string, now time.Time, last int64) (step int64, ok bool) {
	code = strings.ReplaceAll(strings.TrimSpace(code), " ", "")
	if len(code) != totpDigits {
		return 0, false
	}
	cur := totpStep(now)
	for s := cur - 1; s <= cur+1; s++ {
		want, err := totpAt(secret, s)
		if err != nil {
			return 0, false
		}
		if s > last && subtle.ConstantTimeCompare([]byte(want), []byte(code)) == 1 {
			return s, true
		}
	}
	return 0, false
}
