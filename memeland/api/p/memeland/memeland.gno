package memeland

import (
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/seqid"
)

type Post struct {
	ID            string
	Data          string
	Author        std.Address
	Timestamp     time.Time
	UpvoteTracker *avl.Tree // address > struct{}{}
}

type Memeland struct {
	Posts       []*Post
	MemeCounter seqid.ID
}

// NewMemeland returns a pointer to a new Memeland object
// Initializes all the subfields
func NewMemeland() *Memeland {
	var id seqid.ID

	return &Memeland{
		// Posts:       []*Post{},
		// MemeCounter: id.Next().String(),
		// MemeCounter: 0,
	}

	panic("implement me")
}

// PostMeme - Adds a new post at timestamp, with data
// Panics in case data is empty or timestamp is invalid
// Returns the ID of the created Post
func (m *Memeland) PostMeme(data string, timestamp int64) string {
	if data == "" {
        panic("data cannot be empty")
    }
    if timestamp <= 0 {
        panic("timestamp must be positive")
    }

    newPost := &Post{
        ID:            m.MemeCounter.Next().String(),
        Data:          data,
        Timestamp:     time.Unix(timestamp, 0),
        UpvoteTracker: avl.NewTree(), // Make sure this is initialized
    }

    m.Posts = append(m.Posts, newPost)

    return newPost.ID
	
}

// Upvote increases the upvote count of a specific Post
// Panics if specified ID doesn't exist, or the user has already upvoted
func (m *Memeland) Upvote(postID string) string {
    // 고정된 사용자 주소 설정
    userAddress := std.Address("임의_주소")

    // 게시물 ID로 게시물 찾기
    var post *Post
    for _, p := range m.Posts {
        if p.ID == postID {
            post = p
            break
        }
    }
    if post == nil {
        panic("post not found")
    }

    // 사용자가 이미 투표했는지 확인
    // userAddress를 문자열로 변환
    userAddressStr := userAddress.String()
    // if _, exists := post.UpvoteTracker.Get(userAddressStr); exists {
    //     panic("user has already upvoted this post")
    // }

    // 사용자 주소를 업보트 추적기에 추가
    // userAddress를 문자열로 변환하여 추가
    post.UpvoteTracker.Set(userAddressStr, struct{}{})

    return "upvote successful"
}


// sortByDateCreated sorts the posts slice by their creation timestamp in descending order.
func sortByDateCreated(posts []*Post) {
    for i := 0; i < len(posts); i++ {
        for j := 0; j < len(posts)-i-1; j++ {
            if posts[j].Timestamp.Before(posts[j+1].Timestamp) {
                posts[j], posts[j+1] = posts[j+1], posts[j]
            }
        }
    }
}

// sortByUpvotes sorts the posts slice by their upvote count in descending order.
func sortByUpvotes(posts []*Post) {
    for i := 0; i < len(posts); i++ {
        for j := 0; j < len(posts)-i-1; j++ {
            if posts[j].UpvoteTracker.Size() < posts[j+1].UpvoteTracker.Size() {
                posts[j], posts[j+1] = posts[j+1], posts[j]
            }
        }
    }
}

// GetPostsInRange returns a JSON object containing marshalled Posts in a specific timestamp range
// Timestamps are given as Unix seconds
// Supports pagination
// sortBy can be "UPVOTES" (most upvotes-first), or "DATE_CREATED" (newest-first)
// Panics if page < 1, pageSize < 1, or pageSize > 10
// Returns empty JSON object if there are no posts in the specified range.
func (m *Memeland) GetPostsInRange(startTimestamp, endTimestamp int64, page, pageSize int, sortBy string) string {
	if page < 1 {
		panic("page must be positive")
	}
	if pageSize < 1 || pageSize > 10 {
		panic("pageSize must be between 1 and 10")
	}
	if startTimestamp > endTimestamp {
		panic("startTimestamp must be less than or equal to endTimestamp")
	}
	if sortBy != "UPVOTES" && sortBy != "DATE_CREATED" {
		panic("sortBy must be either UPVOTES or DATE_CREATED")
	}

	// Filter posts within the given timestamp range.
	var filteredPosts []*Post
	for _, post := range m.Posts {
		if post.Timestamp.Unix() >= startTimestamp && post.Timestamp.Unix() <= endTimestamp {
			filteredPosts = append(filteredPosts, post)
		}
	}

	// Sort posts based on the sortBy parameter.
	switch sortBy {
	case "DATE_CREATED":
		sortByDateCreated(filteredPosts)

	case "UPVOTES":
		sortByUpvotes(filteredPosts)

	}

	// Apply pagination.
	startIndex := (page - 1) * pageSize
	if startIndex > len(filteredPosts) {
		return "[]" // If the start index exceeds the slice length, return an empty JSON array.
	}
	endIndex := startIndex + pageSize
	if endIndex > len(filteredPosts) {
		endIndex = len(filteredPosts)
	}
	paginatedPosts := filteredPosts[startIndex:endIndex]

	return PostsToJSONString(paginatedPosts)
}


// getPost gets a post by ID
func (m *Memeland) getPost(id string) *Post {
	for _, post := range m.Posts {
		if post.ID == id {
			return post
		}
	}
	return nil
}

// PostsToJSONString converts a slice of Post structs into a JSON string
func PostsToJSONString(posts []*Post) string {
	var sb strings.Builder
	sb.WriteString("[")

	for i, post := range posts {
		if i > 0 {
			sb.WriteString(",")
		}

		sb.WriteString(PostToJSONString(post))
	}
	sb.WriteString("]")

	return sb.String()
}

// PostToJSONString returns a Post formatted as a JSON string
// Note: Gno currently does not support reflection, which is why JSON marshalling is unavailable
func PostToJSONString(post *Post) string {
	var sb strings.Builder

	sb.WriteString("{")
	sb.WriteString(`"id":"` + post.ID + `",`)
	sb.WriteString(`"data":"` + escapeString(post.Data) + `",`)
	sb.WriteString(`"author":"` + escapeString(post.Author.String()) + `",`)
	sb.WriteString(`"timestamp":"` + strconv.Itoa(int(post.Timestamp.Unix())) + `",`)
	sb.WriteString(`"upvotes":` + strconv.Itoa(post.UpvoteTracker.Size()))
	sb.WriteString("}")

	return sb.String()
}

// escapeString escapes quotes in a string for JSON compatibility.
func escapeString(s string) string {
	return strings.ReplaceAll(s, `"`, `\"`)
}
