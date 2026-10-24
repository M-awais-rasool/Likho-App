package handler

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/domain"
	"likho/backend/internal/repository"
	"likho/backend/internal/service"
)

type ControlsHandler struct {
	controls *service.ControlsService
}

// Config: GET /v1/config -> what is on in the app (App controls), for the
// signed-in family or a guest. Answers 304 to an unchanged If-None-Match.
func (h *ControlsHandler) Config(c *gin.Context) {
	out, err := h.controls.ForApp(c.Request.Context(), parentID(c))
	if err != nil {
		writeError(c, err)
		return
	}
	body, err := json.Marshal(out)
	if err != nil {
		writeError(c, err)
		return
	}
	sum := sha256.Sum256(body)
	etag := `"` + hex.EncodeToString(sum[:8]) + `"`
	c.Header("ETag", etag)
	c.Header("Cache-Control", "private, no-cache")
	c.Header("Vary", "Authorization")
	if c.GetHeader("If-None-Match") == etag {
		c.Status(http.StatusNotModified)
		return
	}
	c.Data(http.StatusOK, "application/json; charset=utf-8", body)
}

// ------------------------------------------------------------ admin panel

// controlsMeta describes what can be switched, for the panel.
type controlsMeta struct {
	Features  []featureMeta             `json:"features"`
	Episodes  []domain.Episode          `json:"episodes"`
	GameList  []domain.PlayGame         `json:"gameList"` // the Games screen's games
	Items     []itemMeta                `json:"items"`
	Games     []string                  `json:"games"`
	Colors    []string                  `json:"colors"`
	LastLevel int                       `json:"lastLevel"`
	Defaults  domain.Controls           `json:"defaults"`
	Families  []repository.FeatureCount `json:"families"`
}

type featureMeta struct {
	ID    string   `json:"id"`
	Modes []string `json:"modes"`
}

type itemMeta struct {
	ID    string `json:"id"`
	Price int    `json:"price"` // the price before any change
	Wear  bool   `json:"wear"`
}

// Controls: GET /controls -> {saved, meta}.
func (h *AdminHandler) Controls(c *gin.Context) {
	ctx := c.Request.Context()
	counts, err := h.AppControls.FamilyCounts(ctx)
	if err != nil {
		writeError(c, err)
		return
	}
	meta := controlsMeta{Episodes: domain.StoryEpisodes, GameList: domain.PlayGames, Games: domain.GameTypes, Colors: domain.PencilColorOrder,
		LastLevel: h.AppControls.LastLevel(), Defaults: h.AppControls.Defaults(), Families: counts}
	for _, f := range domain.Features {
		meta.Features = append(meta.Features, featureMeta{f.ID, f.Modes})
	}
	for _, id := range domain.ItemOrder {
		it := domain.Items[id]
		meta.Items = append(meta.Items, itemMeta{it.ID, it.Price, it.Wear})
	}
	writeJSON(c, http.StatusOK, gin.H{"saved": h.AppControls.Saved(ctx), "meta": meta})
}

// SaveControls: PUT /controls {controls, revision} -> the saved controls.
func (h *AdminHandler) SaveControls(c *gin.Context) {
	var in struct {
		Controls domain.Controls `json:"controls"`
		Revision int             `json:"revision"`
	}
	if !bind(c, &in) {
		return
	}
	out, err := h.AppControls.Save(c.Request.Context(), actor(c), in.Controls, in.Revision)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// FamilyFeatures: GET /families/:parentId/features -> the family's switches.
func (h *AdminHandler) FamilyFeatures(c *gin.Context) {
	id, ok := uuidParam(c, "parentId")
	if !ok {
		return
	}
	out, err := h.AppControls.Family(c.Request.Context(), id)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}

// SetFamilyFeatures: PATCH /families/:parentId/features {key: true | false
// | null} -> the family's switches.
func (h *AdminHandler) SetFamilyFeatures(c *gin.Context) {
	id, ok := uuidParam(c, "parentId")
	if !ok {
		return
	}
	var in map[string]*bool
	if !bind(c, &in) {
		return
	}
	out, err := h.AppControls.SetFamily(c.Request.Context(), actor(c), id, in)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, out)
}
