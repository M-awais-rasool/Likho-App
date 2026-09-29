// Package content is Likho's learning content: every course, as authored
// JSON files (see README.md). It is built into the API binary; the API
// loads, checks and serves it through internal/catalog.
package content

import "embed"

// FS holds courses/ (the content) and schema/ (JSON Schemas for editors).
//
//go:embed courses schema
var FS embed.FS
