package handler

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"my_blog/internal/model"
)

type CommentHandler struct {
	DB *gorm.DB
}

// CreateComment 创建评论（需认证）
func (h *CommentHandler) CreateComment(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "未认证"})
		return
	}

	var input struct {
		PostID  uint   `json:"post_id" binding:"required"`
		Content string `json:"content" binding:"required,min=1,max=1000"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 可选：验证文章是否存在
	var post model.Post
	if err := h.DB.First(&post, input.PostID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "文章不存在"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "查询文章失败"})
		}
		return
	}

	comment := model.Comment{
		Content: input.Content,
		PostID:  input.PostID,
		UserID:  userID.(uint),
	}

	if err := h.DB.Create(&comment).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "评论创建失败"})
		return
	}

	c.JSON(http.StatusCreated, comment)
}

// ListComments 获取某篇文章的所有评论（公开）
func (h *CommentHandler) ListComments(c *gin.Context) {
	var input struct {
		PostID uint `json:"post_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 post_id"})
		return
	}

	var comments []model.Comment
	if err := h.DB.
		Preload("User"). // 加载评论作者
		Where("post_id = ?", input.PostID).
		Order("created_at ASC").
		Find(&comments).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取评论失败"})
		return
	}

	c.JSON(http.StatusOK, comments)
}
