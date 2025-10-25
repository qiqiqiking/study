package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"my_blog/internal/model"
)

type PostHandler struct {
	DB *gorm.DB
}

// CreatePost 创建文章（需认证）
func (h *PostHandler) CreatePost(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "未认证"})
		return
	}

	var input struct {
		Title   string `json:"title" binding:"required"`
		Content string `json:"content" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	post := model.Post{
		Title:   input.Title,
		Content: input.Content,
		UserID:  userID.(uint),
	}

	if err := h.DB.Create(&post).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建文章失败"})
		return
	}

	h.DB.Preload("User").First(&post, post.ID)
	c.JSON(http.StatusCreated, post)
}

// ListPosts 获取所有文章列表（公开）
func (h *PostHandler) ListPosts(c *gin.Context) {
	var input struct {
		Page int `json:"page"`
		Size int `json:"size"`
	}
	_ = c.ShouldBindJSON(&input) // 不强制校验，可选

	query := h.DB.Preload("User")
	if input.Size > 0 {
		query = query.Limit(input.Size)
	}
	if input.Page > 0 {
		offset := (input.Page - 1) * input.Size
		query = query.Offset(offset)
	}

	var posts []model.Post
	if err := query.Find(&posts).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取文章列表失败"})
		return
	}
	c.JSON(http.StatusOK, posts)
}

// GetPost 获取单篇文章详情（公开）
func (h *PostHandler) GetPost(c *gin.Context) {
	var input struct {
		ID uint `json:"id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少文章ID"})
		return
	}

	var post model.Post
	if err := h.DB.Preload("User").First(&post, input.ID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "文章不存在"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "查询失败"})
		}
		return
	}
	c.JSON(http.StatusOK, post)
}

// UpdatePost 更新文章（仅作者）
func (h *PostHandler) UpdatePost(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "未认证"})
		return
	}

	var input struct {
		ID      uint    `json:"id" binding:"required"`
		Title   *string `json:"title"`
		Content *string `json:"content"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var post model.Post
	if err := h.DB.First(&post, input.ID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "文章不存在"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "查询失败"})
		}
		return
	}

	// 权限检查：只有作者能修改
	if post.UserID != userID.(uint) {
		c.JSON(http.StatusForbidden, gin.H{"error": "无权修改此文章"})
		return
	}

	if input.Title != nil {
		post.Title = *input.Title
	}
	if input.Content != nil {
		post.Content = *input.Content
	}

	if err := h.DB.Save(&post).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新失败"})
		return
	}

	h.DB.Preload("User").First(&post, post.ID)
	c.JSON(http.StatusOK, post)
}

// DeletePost 删除文章（仅作者）
func (h *PostHandler) DeletePost(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "未认证"})
		return
	}

	var input struct {
		ID uint `json:"id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少文章ID"})
		return
	}

	var post model.Post
	if err := h.DB.First(&post, input.ID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "文章不存在"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "查询失败"})
		}
		return
	}

	if post.UserID != userID.(uint) {
		c.JSON(http.StatusForbidden, gin.H{"error": "无权删除此文章"})
		return
	}

	if err := h.DB.Delete(&post).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "文章已删除"})
}
