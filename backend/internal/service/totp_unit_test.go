package service

import (
	"encoding/base32"
	"strings"
	"testing"
	"time"
)

// RFC 6238 appendix B (SHA-1, 8 digits there): the last 6 digits.
func TestTOTPMatchesTheRFC(t *testing.T) {
	secret := base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString([]byte("12345678901234567890"))
	for unix, want := range map[int64]string{59: "287082", 1111111109: "081804", 1234567890: "005924", 2000000000: "279037"} {
		got, err := TOTPCode(secret, time.Unix(unix, 0))
		if err != nil || got != want {
			t.Errorf("at %d: %q, %v; want %q", unix, got, err, want)
		}
	}
}

func TestTOTPCheck(t *testing.T) {
	secret, err := NewTOTPSecret()
	if err != nil || len(secret) != 32 {
		t.Fatalf("secret %q, %v", secret, err)
	}
	now := time.Unix(1_800_000_000, 0)
	code, _ := TOTPCode(secret, now)
	step, ok := checkTOTP(secret, code[:3]+" "+code[3:], now, 0)
	if !ok || step != totpStep(now) {
		t.Fatalf("today's code (with a space): %v %v", step, ok)
	}
	if _, ok := checkTOTP(secret, code, now, step); ok {
		t.Error("a code works once")
	}
	late, _ := TOTPCode(secret, now.Add(-30*time.Second))
	if _, ok := checkTOTP(secret, late, now, 0); !ok {
		t.Error("the code from just before is still taken")
	}
	old, _ := TOTPCode(secret, now.Add(-2*time.Minute))
	if _, ok := checkTOTP(secret, old, now, 0); ok && old != code {
		t.Error("a code from two minutes ago is refused")
	}
	for _, bad := range []string{"", "12345", "1234567", "abcdef"} {
		if _, ok := checkTOTP(secret, bad, now, 0); ok {
			t.Errorf("%q accepted", bad)
		}
	}
	if u := TOTPURL(secret, "a@b.c"); !strings.HasPrefix(u, "otpauth://totp/Likho%20Admin:a@b.c?") || !strings.Contains(u, "secret="+secret) || !strings.Contains(u, "issuer=Likho+Admin") {
		t.Errorf("url %s", u)
	}
}
