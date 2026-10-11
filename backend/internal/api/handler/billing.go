package handler

import (
	"io"
	"net/http"

	"github.com/gin-gonic/gin"

	"likho/backend/internal/domain"
	"likho/backend/internal/service"
)

// BillingHandler: Likho Plus bought in Google Play.
type BillingHandler struct {
	billing *service.BillingService
}

// VerifyGoogle: POST /v1/me/purchases/google {"productId", "purchaseToken"}
// -> {"subscription"}. The app sends every purchase and restore here.
func (h *BillingHandler) VerifyGoogle(c *gin.Context) {
	var in struct {
		ProductID     string `json:"productId"`
		PurchaseToken string `json:"purchaseToken"`
	}
	if !bind(c, &in) {
		return
	}
	out, err := h.billing.VerifyGoogle(c.Request.Context(), parentID(c), in.ProductID, in.PurchaseToken)
	if err != nil {
		writeError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, gin.H{"subscription": out})
}

// Notify: POST /v1/play/notifications?key= — Google Play's real-time
// developer notifications, pushed by Pub/Sub. 204 = handled; an error
// makes Pub/Sub push it again later.
func (h *BillingHandler) Notify(c *gin.Context) {
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		writeError(c, domain.Invalid("body could not be read"))
		return
	}
	if err := h.billing.Notify(c.Request.Context(), c.Query("key"), body); err != nil {
		writeError(c, err)
		return
	}
	noContent(c)
}
