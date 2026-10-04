package catalog

import (
	"errors"
	"io/fs"
	"path"
	"sort"
	"testing/fstest"
	"time"
)

// Overlay returns [base] with [files] laid over it: a file in [files]
// replaces the base file at the same path or adds a new one (its folders
// appear too). The admin panel publishes content this way: new and edited
// levels live in the database and are checked and served exactly like the
// files in content/.
func Overlay(base fs.FS, files map[string][]byte) fs.FS {
	if len(files) == 0 {
		return base
	}
	top := fstest.MapFS{}
	for name, data := range files {
		top[name] = &fstest.MapFile{Data: data, Mode: 0o444, ModTime: time.Unix(0, 0)}
	}
	return overlayFS{base: base, top: top}
}

type overlayFS struct {
	base fs.FS
	top  fstest.MapFS
}

func (o overlayFS) Open(name string) (fs.File, error) {
	if f, ok := o.top[name]; ok && !f.Mode.IsDir() {
		return o.top.Open(name)
	}
	if f, err := o.base.Open(name); err == nil {
		return f, nil
	}
	return o.top.Open(name)
}

func (o overlayFS) ReadFile(name string) ([]byte, error) {
	if f, ok := o.top[name]; ok {
		return append([]byte(nil), f.Data...), nil
	}
	return fs.ReadFile(o.base, name)
}

func (o overlayFS) Stat(name string) (fs.FileInfo, error) {
	if _, ok := o.top[name]; ok {
		return o.top.Stat(name)
	}
	if fi, err := fs.Stat(o.base, name); err == nil {
		return fi, nil
	}
	return o.top.Stat(name)
}

// ReadDir merges both listings (the top entry wins on a name clash).
func (o overlayFS) ReadDir(name string) ([]fs.DirEntry, error) {
	byName := map[string]fs.DirEntry{}
	baseEntries, baseErr := fs.ReadDir(o.base, name)
	for _, e := range baseEntries {
		byName[e.Name()] = e
	}
	topEntries, topErr := o.top.ReadDir(path.Clean(name))
	for _, e := range topEntries {
		byName[e.Name()] = e
	}
	if baseErr != nil && topErr != nil {
		return nil, errors.Join(baseErr, topErr)
	}
	out := make([]fs.DirEntry, 0, len(byName))
	for _, e := range byName {
		out = append(out, e)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name() < out[j].Name() })
	return out, nil
}
