// Command content checks and builds Likho's course content (backend/content).
//
//	go run ./cmd/content validate              check every course (drafts too)
//	go run ./cmd/content list                  courses with their size and version
//	go run ./cmd/content bundle <course-id>    the document the API serves, to stdout
//	    -o file   write it to a file instead
//	    -indent   pretty-print (for fixtures and diffs)
//
// -dir points at another content folder (default: ./content).
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"text/tabwriter"

	"likho/backend/internal/catalog"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func usage() error {
	return fmt.Errorf("usage: content [-dir content] validate | list | bundle <course-id> [-o file] [-indent]")
}

func run(args []string) error {
	fl := flag.NewFlagSet("content", flag.ContinueOnError)
	dir := fl.String("dir", "content", "content folder (contains courses/)")
	if err := fl.Parse(args); err != nil {
		return err
	}
	if fl.NArg() == 0 {
		return usage()
	}
	cat, err := catalog.Load(os.DirFS(*dir), catalog.Options{IncludeDrafts: true})
	if err != nil {
		return err
	}

	switch cmd, rest := fl.Arg(0), fl.Args()[1:]; cmd {
	case "validate":
		for _, c := range cat.Courses() {
			fmt.Printf("ok  %-24s %d worlds, %d levels, %d rounds  %s\n", c.Summary.ID, c.Stats.Worlds, c.Stats.Levels, c.Stats.Rounds, c.ETag)
		}
		return nil

	case "list":
		w := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
		fmt.Fprintln(w, "ID\tTITLE\tSTATUS\tWORLDS\tLEVELS\tVERSION")
		for _, c := range cat.Courses() {
			status := "published"
			if c.Draft {
				status = "draft"
			}
			fmt.Fprintf(w, "%s\t%s\t%s\t%d\t%d\t%s\n", c.Summary.ID, c.Summary.Title, status, c.Stats.Worlds, c.Stats.Levels, c.Summary.Version)
		}
		return w.Flush()

	case "bundle":
		bf := flag.NewFlagSet("bundle", flag.ContinueOnError)
		out := bf.String("o", "", "write to this file instead of stdout")
		indent := bf.Bool("indent", false, "pretty-print")
		if len(rest) == 0 {
			return usage()
		}
		id := rest[0]
		if err := bf.Parse(rest[1:]); err != nil {
			return err
		}
		c, ok := cat.Course(id)
		if !ok {
			return fmt.Errorf("no course %q", id)
		}
		body := c.JSON
		if *indent {
			var b bytes.Buffer
			if err := json.Indent(&b, c.JSON, "", "  "); err != nil {
				return err
			}
			b.WriteByte('\n')
			body = b.Bytes()
		}
		if *out == "" {
			_, err := os.Stdout.Write(body)
			return err
		}
		return os.WriteFile(*out, body, 0o644)
	}
	return usage()
}
