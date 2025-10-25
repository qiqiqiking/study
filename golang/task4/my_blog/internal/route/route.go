package route

import (
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"log"
	"my_blog/internal/middleware"

	"my_blog/internal/handler"
)

func RegisterRoutes(r *gin.Engine, db *gorm.DB) {
	authHandler := &handler.AuthHandler{DB: db}
	postHandler := &handler.PostHandler{DB: db}
	commentHandler := &handler.CommentHandler{DB: db}

	public := r.Group("/api")
	{
		public.GET("/post/list", postHandler.ListPosts)
		public.GET("/post/get", postHandler.GetPost)
		public.POST("/comment/list", commentHandler.ListComments)
	}
	protected := r.Group("/api")
	protected.Use(middleware.AuthMiddleware())
	{
		protected.POST("/register", authHandler.Register)
		protected.POST("/login", authHandler.Login)
		protected.POST("/post/add", postHandler.CreatePost)
		protected.POST("/post/update", postHandler.UpdatePost)
		protected.POST("/post/delete", postHandler.DeletePost)

		protected.POST("/comment/add", commentHandler.CreateComment)
	}

	log.Println("✅ Routes registered")

}
