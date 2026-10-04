package model

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
)

// JSON is a jsonb column: any JSON value, stored and read as is.
type JSON json.RawMessage

// JSONOf encodes [v] (an object of details, a setting…).
func JSONOf(v any) JSON {
	b, err := json.Marshal(v)
	if err != nil || len(b) == 0 {
		return JSON("{}")
	}
	return JSON(b)
}

func (j JSON) Value() (driver.Value, error) {
	if len(j) == 0 {
		return "{}", nil
	}
	return string(j), nil
}

func (j *JSON) Scan(src any) error {
	switch v := src.(type) {
	case []byte:
		*j = append(JSON(nil), v...)
	case string:
		*j = JSON(v)
	case nil:
		*j = nil
	default:
		return errors.New("model.JSON: unsupported type")
	}
	return nil
}

func (j JSON) MarshalJSON() ([]byte, error) {
	if len(j) == 0 {
		return []byte("{}"), nil
	}
	return j, nil
}

func (j *JSON) UnmarshalJSON(b []byte) error {
	*j = append(JSON(nil), b...)
	return nil
}
