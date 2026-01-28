# Developer 3 Guide - Content & Notification Services (Mid-Level)

> **Your Services**: content-service, notification-service  
> **Complexity**: 🟡 Medium  
> **Estimated LOC**: 3,000  
> **Timeline**: Week 2-4

---

## 🎯 Your Responsibilities

You are the **User-Facing Features Owner**. Your work enables social content sharing.

### Services Overview

1. **content-service** (Week 2-3)
   - Story module (create, view, react)
   - Timeline module (posts, likes, comments)
   - Privacy settings integration

2. **notification-service** (Week 3-4)
   - Push notification (FCM)
   - Device token management
   - Event listeners (RabbitMQ)

---

## 📦 Week 2-3: content-service

### Day 1: Create Module

**pom.xml**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <parent>
        <groupId>vn.edu.hcmuaf.fit.ott</groupId>
        <artifactId>cnm-zalo-backend</artifactId>
        <version>1.0.0-SNAPSHOT</version>
        <relativePath>../../pom.xml</relativePath>
    </parent>

    <artifactId>content-service</artifactId>

    <dependencies>
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-security</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Day 2-7: Story Module

#### 1. Story Entity

```java
// content-service/src/main/java/.../content/entity/Story.java
@Entity
@Table(name = "story", schema = "content")
@Getter
@Setter
public class Story extends BaseEntity {
    
    @Column(name = "user_id", nullable = false)
    private UUID userId;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "story_type", length = 20, nullable = false)
    private StoryType storyType;  // IMAGE, VIDEO, TEXT
    
    @Column(name = "media_id")
    private UUID mediaId;
    
    @Column(name = "media_url")
    private String mediaUrl;
    
    @Column(name = "text_content", columnDefinition = "TEXT")
    private String textContent;
    
    @Column(name = "background_color", length = 20)
    private String backgroundColor;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "visibility", length = 20)
    private StoryVisibility visibility = StoryVisibility.FRIENDS;
    
    @Column(name = "view_count")
    private Integer viewCount = 0;
    
    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;
    
    @Column(name = "is_active")
    private Boolean isActive = true;
}
```

#### 2. Story Service

```java
// content-service/src/main/java/.../content/service/StoryService.java
@Service
@RequiredArgsConstructor
@Transactional
public class StoryService {
    
    private final StoryRepository storyRepository;
    private final StoryViewRepository storyViewRepository;
    private final FriendshipClient friendshipClient;  // Feign client to core-service
    
    public Story createStory(CreateStoryRequest request, UUID userId) {
        Story story = new Story();
        story.setUserId(userId);
        story.setStoryType(request.getStoryType());
        story.setMediaId(request.getMediaId());
        story.setMediaUrl(request.getMediaUrl());
        story.setTextContent(request.getTextContent());
        story.setVisibility(request.getVisibility());
        story.setExpiresAt(LocalDateTime.now().plusHours(24));  // 24h expiry
        
        return storyRepository.save(story);
    }
    
    public List<StoryDTO> getActiveStories(UUID viewerUserId) {
        // Get viewer's friends
        List<UUID> friendIds = friendshipClient.getFriendIds(viewerUserId);
        
        // Add viewer to see own stories
        friendIds.add(viewerUserId);
        
        // Get active stories from friends
        LocalDateTime now = LocalDateTime.now();
        List<Story> stories = storyRepository.findActiveStoriesByUsers(friendIds, now);
        
        // Convert to DTO and check if viewed
        return stories.stream()
            .map(story -> {
                boolean viewed = storyViewRepository.existsByStoryIdAndViewerId(
                    story.getId(), viewerUserId
                );
                return StoryDTO.from(story, viewed);
            })
            .collect(Collectors.toList());
    }
    
    public void viewStory(UUID storyId, UUID viewerId) {
        Story story = storyRepository.findById(storyId)
            .orElseThrow(() -> new StoryNotFoundException("Story not found"));
        
        // Check if already viewed
        if (storyViewRepository.existsByStoryIdAndViewerId(storyId, viewerId)) {
            return;
        }
        
        // Create view record
        StoryView view = new StoryView();
        view.setStoryId(storyId);
        view.setViewerId(viewerId);
        storyViewRepository.save(view);
        
        // Increment view count
        story.setViewCount(story.getViewCount() + 1);
        storyRepository.save(story);
    }
}
```

#### 3. Story Controller

```java
// content-service/src/main/java/.../content/controller/StoryController.java
@RestController
@RequestMapping("/api/v1/stories")
@RequiredArgsConstructor
public class StoryController {
    
    private final StoryService storyService;
    
    @PostMapping
    public ResponseEntity<StoryDTO> createStory(
            @Valid @RequestBody CreateStoryRequest request,
            @AuthenticationPrincipal UserPrincipal user) {
        
        Story story = storyService.createStory(request, user.getUserId());
        return ResponseEntity.status(HttpStatus.CREATED).body(StoryDTO.from(story, false));
    }
    
    @GetMapping
    public ResponseEntity<List<StoryDTO>> getStories(
            @AuthenticationPrincipal UserPrincipal user) {
        
        List<StoryDTO> stories = storyService.getActiveStories(user.getUserId());
        return ResponseEntity.ok(stories);
    }
    
    @PostMapping("/{storyId}/view")
    public ResponseEntity<Void> viewStory(
            @PathVariable UUID storyId,
            @AuthenticationPrincipal UserPrincipal user) {
        
        storyService.viewStory(storyId, user.getUserId());
        return ResponseEntity.ok().build();
    }
}
```

### Day 8-14: Timeline Module

#### 1. Timeline Post Entity

```java
// content-service/src/main/java/.../content/entity/TimelinePost.java
@Entity
@Table(name = "timeline_post", schema = "content")
@Getter
@Setter
public class TimelinePost extends BaseEntity {
    
    @Column(name = "user_id", nullable = false)
    private UUID userId;
    
    @Column(name = "content", columnDefinition = "TEXT")
    private String content;
    
    @ElementCollection
    @CollectionTable(name = "timeline_post_media", schema = "content")
    @Column(name = "media_id")
    private List<UUID> mediaIds = new ArrayList<>();
    
    @Enumerated(EnumType.STRING)
    @Column(name = "privacy", length = 20)
    private PostPrivacy privacy = PostPrivacy.FRIENDS;
    
    @Column(name = "like_count")
    private Integer likeCount = 0;
    
    @Column(name = "comment_count")
    private Integer commentCount = 0;
    
    @Column(name = "share_count")
    private Integer shareCount = 0;
    
    @Column(name = "is_deleted")
    private Boolean isDeleted = false;
}
```

#### 2. Timeline Service

```java
// content-service/src/main/java/.../content/service/TimelineService.java
@Service
@RequiredArgsConstructor
@Transactional
public class TimelineService {
    
    private final TimelinePostRepository postRepository;
    private final TimelineLikeRepository likeRepository;
    private final TimelineCommentRepository commentRepository;
    
    public TimelinePost createPost(CreatePostRequest request, UUID userId) {
        TimelinePost post = new TimelinePost();
        post.setUserId(userId);
        post.setContent(request.getContent());
        post.setMediaIds(request.getMediaIds());
        post.setPrivacy(request.getPrivacy());
        
        return postRepository.save(post);
    }
    
    public void likePost(UUID postId, UUID userId) {
        TimelinePost post = postRepository.findById(postId)
            .orElseThrow(() -> new PostNotFoundException("Post not found"));
        
        // Check if already liked
        if (likeRepository.existsByPostIdAndUserId(postId, userId)) {
            return;
        }
        
        // Create like
        TimelineLike like = new TimelineLike();
        like.setPostId(postId);
        like.setUserId(userId);
        likeRepository.save(like);
        
        // Increment like count
        post.setLikeCount(post.getLikeCount() + 1);
        postRepository.save(post);
    }
    
    public TimelineComment addComment(UUID postId, String content, UUID userId) {
        TimelinePost post = postRepository.findById(postId)
            .orElseThrow(() -> new PostNotFoundException("Post not found"));
        
        TimelineComment comment = new TimelineComment();
        comment.setPostId(postId);
        comment.setUserId(userId);
        comment.setContent(content);
        commentRepository.save(comment);
        
        // Increment comment count
        post.setCommentCount(post.getCommentCount() + 1);
        postRepository.save(post);
        
        return comment;
    }
}
```

---

## 📲 Week 3-4: notification-service

### Day 1-2: Setup FCM

#### 1. Add FCM SDK

```xml
<dependency>
    <groupId>com.google.firebase</groupId>
    <artifactId>firebase-admin</artifactId>
    <version>9.2.0</version>
</dependency>
```

#### 2. FCM Configuration

```java
// notification-service/src/main/java/.../notification/config/FirebaseConfig.java
@Configuration
public class FirebaseConfig {
    
    @Value("${firebase.config.path}")
    private String firebaseConfigPath;
    
    @PostConstruct
    public void initialize() throws IOException {
        FileInputStream serviceAccount = new FileInputStream(firebaseConfigPath);
        
        FirebaseOptions options = FirebaseOptions.builder()
            .setCredentials(GoogleCredentials.fromStream(serviceAccount))
            .build();
        
        FirebaseApp.initializeApp(options);
    }
}
```

#### 3. FCM Service

```java
// notification-service/src/main/java/.../notification/service/FcmService.java
@Service
@Slf4j
public class FcmService {
    
    public void sendNotification(String token, String title, String body, Map<String, String> data) {
        try {
            Message message = Message.builder()
                .setToken(token)
                .setNotification(Notification.builder()
                    .setTitle(title)
                    .setBody(body)
                    .build())
                .putAllData(data)
                .build();
            
            String response = FirebaseMessaging.getInstance().send(message);
            log.info("Successfully sent FCM: {}", response);
            
        } catch (FirebaseMessagingException e) {
            log.error("Failed to send FCM: {}", e.getMessage());
        }
    }
}
```

#### 4. RabbitMQ Listener

```java
// notification-service/src/main/java/.../notification/listener/MessageEventListener.java
@Component
@RequiredArgsConstructor
@Slf4j
public class MessageEventListener {
    
    private final FcmService fcmService;
    private final DeviceTokenRepository deviceTokenRepository;
    private final UserClient userClient;
    
    @RabbitListener(queues = "message.sent")
    public void handleMessageEvent(MessageSentEvent event) {
        log.info("Received message event: {}", event);
        
        // Get recipient's device tokens
        List<String> tokens = deviceTokenRepository
            .findActiveTokensByUserId(event.getRecipientId());
        
        // Get sender info
        UserDTO sender = userClient.getUserById(event.getSenderId());
        
        // Send push notification
        tokens.forEach(token -> {
            fcmService.sendNotification(
                token,
                sender.getDisplayName(),
                event.getMessagePreview(),
                Map.of(
                    "type", "NEW_MESSAGE",
                    "conversationId", event.getConversationId().toString(),
                    "messageId", event.getMessageId().toString()
                )
            );
        });
    }
}
```

---

## 📝 Testing

### Test Story API

```bash
# Create story
curl -X POST http://localhost:8084/api/v1/stories \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "storyType": "IMAGE",
    "mediaId": "uuid-here",
    "mediaUrl": "https://cloudinary.../image.jpg",
    "visibility": "FRIENDS"
  }'

# Get stories
curl http://localhost:8084/api/v1/stories \
  -H "Authorization: Bearer YOUR_JWT"
```

### Test Notification

```bash
# Register device token
curl -X POST http://localhost:8086/api/v1/notifications/register \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "FCM_TOKEN_HERE",
    "platform": "ANDROID"
  }'
```

---

## ✅ Checklist

### Content Service
- [ ] Create content-service module
- [ ] Implement Story entity & repository
- [ ] Implement Story service (create, view, list)
- [ ] Implement Story controller
- [ ] Implement Timeline Post entity
- [ ] Implement Timeline service (create, like, comment)
- [ ] Test all Story APIs
- [ ] Test all Timeline APIs

### Notification Service
- [ ] Setup Firebase project
- [ ] Create notification-service module
- [ ] Configure FCM SDK
- [ ] Implement device token management
- [ ] Implement RabbitMQ listeners
- [ ] Test push notifications
- [ ] Integration test with messaging-service

---

*Complete! Move to integration testing in Week 4*
