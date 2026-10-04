package service

import (
	"likho/backend/internal/catalog"
	"likho/backend/internal/domain"
	"likho/backend/internal/model"
)

// CourseService: the learning content (read-only, from memory).
type CourseService struct {
	catalog *catalog.Store
}

func NewCourseService(cat *catalog.Store) *CourseService { return &CourseService{catalog: cat} }

// List describes every course that is served.
func (s *CourseService) List() []model.CourseSummary {
	out := []model.CourseSummary{}
	for _, c := range s.catalog.Get().Courses() {
		out = append(out, c.Summary)
	}
	return out
}

// Get returns a course, ready to send (JSON, gzip, ETag).
func (s *CourseService) Get(id string) (*catalog.Course, error) {
	c, ok := s.catalog.Get().Course(id)
	if !ok {
		return nil, domain.ErrCourseNotFound
	}
	return c, nil
}
