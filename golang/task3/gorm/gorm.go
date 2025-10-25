package main

import (
	"errors"
	"gorm.io/gorm"
)

// User 添加文章数量字段
type User struct {
	ID        uint   `gorm:"column:id;type:int unsigned;primaryKey;autoIncrement"`
	Name      string `gorm:"column:name;type:varchar(100);not null"`
	Email     string `gorm:"column:email;type:varchar(255);not null;uniqueIndex"`
	PostCount int    `gorm:"column:post_count;type:int unsigned;not null;default:0"` // 新增
}

func (*User) TableName() string { return "user" }

// Post 添加评论状态字段
type Post struct {
	ID            uint   `gorm:"column:id;type:int unsigned;primaryKey;autoIncrement"`
	Title         string `gorm:"column:title;type:varchar(255);not null"`
	Content       string `gorm:"column:content;type:longtext;not null"`
	UserID        uint   `gorm:"column:user_id;type:int unsigned;not null;index"`
	CommentStatus string `gorm:"column:comment_status;type:varchar(20);not null;default:'has_comments'"` // 新增
}

func (*Post) TableName() string { return "post" }

// Comment 不变
type Comment struct {
	ID      uint   `gorm:"column:id;type:int unsigned;primaryKey;autoIncrement"`
	Content string `gorm:"column:content;type:text;not null"`
	PostID  uint   `gorm:"column:post_id;type:int unsigned;not null;index"`
	UserID  uint   `gorm:"column:user_id;type:int unsigned;not null;index"`
}

func (*Comment) TableName() string { return "comment" }

type PostWithComments struct {
	Post     Post
	Comments []Comment
}

func GetUserPostsAndComments(db *gorm.DB, userID uint) ([]PostWithComments, error) {
	var posts []Post
	if err := db.Where("user_id = ?", userID).Find(&posts).Error; err != nil {
		return nil, err
	}

	if len(posts) == 0 {
		return []PostWithComments{}, nil
	}

	postIDs := make([]uint, len(posts))
	for i, p := range posts {
		postIDs[i] = p.ID
	}

	var comments []Comment
	if err := db.Where("post_id IN ?", postIDs).Find(&comments).Error; err != nil {
		return nil, err
	}

	commentMap := make(map[uint][]Comment)
	for _, c := range comments {
		commentMap[c.PostID] = append(commentMap[c.PostID], c)
	}

	result := make([]PostWithComments, len(posts))
	for i, p := range posts {
		result[i] = PostWithComments{
			Post:     p,
			Comments: commentMap[p.ID],
		}
	}

	return result, nil
}

type PostWithCommentCount struct {
	Post         Post
	CommentCount int64
}

func GetPostWithMostComments(db *gorm.DB) (*PostWithCommentCount, error) {
	type Result struct {
		PostID       uint
		CommentCount int64
	}

	var result Result
	err := db.Table("comment").
		Select("post_id, COUNT(*) as comment_count").
		Group("post_id").
		Order("comment_count DESC").
		First(&result).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}

	var post Post
	if err := db.First(&post, result.PostID).Error; err != nil {
		return nil, err
	}

	return &PostWithCommentCount{
		Post:         post,
		CommentCount: result.CommentCount,
	}, nil
}

func (p *Post) AfterCreate(tx *gorm.DB) error {
	return tx.Model(&User{}).
		Where("id = ?", p.UserID).
		Update("post_count", gorm.Expr("post_count + 1")).
		Error
}

func (c *Comment) AfterDelete(tx *gorm.DB) error {
	var count int64
	tx.Model(&Comment{}).Where("post_id = ?", c.PostID).Count(&count)

	if count == 0 {
		// 无评论，更新文章状态
		return tx.Model(&Post{}).
			Where("id = ?", c.PostID).
			Update("comment_status", "no_comments").
			Error
	}
	return tx.Model(&Post{}).
		Where("id = ?", c.PostID).
		Where("comment_status = ?", "no_comments").
		Update("comment_status", "has_comments").
		Error
}
