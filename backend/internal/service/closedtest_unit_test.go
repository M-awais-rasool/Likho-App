package service

import (
	"testing"
	"time"
)

func TestNormalizeEmail(t *testing.T) {
	for in, want := range map[string]string{
		" Ali.Khan@Gmail.com ":      "alikhan@gmail.com",
		"a.li.khan+phone@gmail.com": "alikhan@gmail.com",
		"alikhan@googlemail.com":    "alikhan@gmail.com",
		"Sara.B+x@Outlook.com":      "sara.b+x@outlook.com", // only Gmail ignores dots and tags
		"no-at-sign":                "",
		"@gmail.com":                "",
	} {
		if got := normalizeEmail(in); got != want {
			t.Errorf("normalizeEmail(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestWhatsAppNumber(t *testing.T) {
	for in, want := range map[string]string{
		"0300 1234567":      "923001234567", // Pakistani mobile, local form
		"+92 300 1234567":   "923001234567",
		"0092-300-1234567":  "923001234567",
		"+1 (415) 555-0100": "14155550100",
		"":                  "",
	} {
		if got := whatsAppNumber(in); got != want {
			t.Errorf("whatsAppNumber(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestClosedTestDays(t *testing.T) {
	c, err := ClosedTestSettings{StartDate: "2026-10-12", Days: 14, Needed: 12, TimeZone: "Asia/Karachi", Plus: true}.clean()
	if err != nil {
		t.Fatal(err)
	}
	if c.PlusUntil != "2026-11-24" || c.Reminder == "" {
		t.Fatalf("defaults: %+v", c)
	}
	// 20:30 UTC on the 12th is already the 13th in Pakistan (UTC+5)
	w, ok := c.recording(time.Date(2026, 10, 12, 20, 30, 0, 0, time.UTC))
	if !ok || w.today.Format(dateLayout) != "2026-10-13" || w.end.Format(dateLayout) != "2026-10-25" {
		t.Fatalf("window: %v %+v", ok, w)
	}
	// Plus lasts to the end of PlusUntil there
	if end := c.plusEnd(w); !end.Equal(time.Date(2026, 11, 24, 19, 0, 0, 0, time.UTC)) {
		t.Errorf("plus ends %v", end)
	}
	// after the last day nothing is recorded
	if _, ok := c.recording(time.Date(2026, 10, 25, 19, 30, 0, 0, time.UTC)); ok {
		t.Error("recording after the test")
	}
	if _, ok := (ClosedTestSettings{TimeZone: "Asia/Karachi", Days: 14}).recording(time.Now()); ok {
		t.Error("recording without a test")
	}
	for _, bad := range []ClosedTestSettings{
		{StartDate: "12/10/2026", Days: 14, Needed: 12},
		{StartDate: "2026-10-12", Days: 0, Needed: 12},
		{StartDate: "2026-10-12", Days: 14, Needed: 12, TimeZone: "Mars/Base"},
		{StartDate: "2026-10-12", Days: 14, Needed: 12, PlusUntil: "2026-10-01"},
		{StartDate: "2026-10-12", Days: 14, Needed: 12, OptInURL: "http://play.google.com/apps/testing/x"},
	} {
		if _, err := bad.clean(); err == nil {
			t.Errorf("accepted %+v", bad)
		}
	}
}
