# Developer 2 Guide - Realtime & Media Services (Mid-Senior)

> **Your Services**: realtime-gateway, media-service  
> **Complexity**: 🟡 Medium-High  
> **Estimated LOC**: 4,500  
> **Timeline**: Week 2-3

---

## 🎯 Your Responsibilities

You are the **Real-time & Media Owner**. Your work enables live messaging and media sharing.

### Services Overview

1. **realtime-gateway** (Week 2-3)
   - WebSocket connection management
   - Presence system (online/offline)
   - Typing indicators
   - Real-time message broadcasting

2. **media-service** (Week 2-3)
   - Media upload (Cloudinary integration)
   - Presigned URL generation
   - Sticker management
   - Background processing

---

## 📦 Setup (Day 1)

### Prerequisites

Ensure Dev 1 has completed:
- ✅ Common modules (common-domain, common-security)
- ✅ Docker Compose setup

### Step 1: Install Cloudinary SDK

Add to parent POM `<dependencyManagement>`:

```xml
<dependency>
    <groupId>com.cloudinary</groupId>
    <artifactId>cloudinary-http44</artifactId>
    <version>1.36.0</version>
</dependency>
```

### Step 2: Sign up for Cloudinary

1. Go to https://cloudinary.com/users/register/free
2. Create account (FREE tier: 25GB)
3. Get credentials from dashboard:
   - Cloud name
   - API Key
   - API Secret

---

## 🌐 Week 1-2: realtime-gateway

### Day 1-2: Create Module

```bash
# In IntelliJ
Right-click services/ → New → Module
Name: realtime-gateway
```

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

    <artifactId>realtime-gateway</artifactId>

    <dependencies>
        <!-- Internal -->
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-security</artifactId>
        </dependency>
        
        <!-- Spring Boot -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-websocket</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        
        <!-- WebSocket -->
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-messaging</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Day 3-5: WebSocket Implementation

#### 1. WebSocket Configuration

```java
// realtime-gateway/src/main/java/.../gateway/config/WebSocketConfig.java
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // Enable simple broker for destinations
        config.enableSimpleBroker("/topic", "/queue");
        
        // Set application destination prefix
        config.setApplicationDestinationPrefixes("/app");
        
        // Set user destination prefix
        config.setUserDestinationPrefix("/user");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }
}
```

#### 2. WebSocket Security

```java
// realtime-gateway/src/main/java/.../gateway/config/WebSocketSecurityConfig.java
@Configuration
@RequiredArgsConstructor
public class WebSocketSecurityConfig {
    
    private final JwtTokenProvider jwtTokenProvider;
    
    @Bean
    public ChannelInterceptor authChannelInterceptor() {
        return new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor = MessageHeaderAccessor
                        .getAccessor(message, StompHeaderAccessor.class);
                
                if (StompCommand.CONNECT.equals(accessor.getCommand())) {
                    // Extract JWT from header
                    String token = accessor.getFirstNativeHeader("Authorization");
                    
                    if (token != null && token.startsWith("Bearer ")) {
                        token = token.substring(7);
                        
                        if (jwtTokenProvider.validateToken(token)) {
                            UUID userId = jwtTokenProvider.getUserIdFromToken(token);
                            accessor.setUser(new UserPrincipal(userId));
                        } else {
                            throw new IllegalArgumentException("Invalid JWT token");
                        }
                    }
                }
                
                return message;
            }
        };
    }
}
```

#### 3. Message Controller

```java
// realtime-gateway/src/main/java/.../gateway/controller/MessageWebSocketController.java
@Controller
@RequiredArgsConstructor
@Slf4j
public class MessageWebSocketController {
    
    private final SimpMessagingTemplate messagingTemplate;
    private final RedisTemplate<String, String> redisTemplate;
    
    @MessageMapping("/message.send")
    public void handleMessage(@Payload MessageDTO message, Principal principal) {
        UserPrincipal user = (UserPrincipal) principal;
        log.info("Received message from user {}: {}", user.getUserId(), message);
        
        // Broadcast to conversation members
        messagingTemplate.convertAndSend(
            "/topic/conversation." + message.getConversationId(),
            message
        );
    }
    
    @MessageMapping("/typing.start")
    public void handleTypingStart(@Payload TypingDTO typing, Principal principal) {
        UserPrincipal user = (UserPrincipal) principal;
        
        messagingTemplate.convertAndSend(
            "/topic/conversation." + typing.getConversationId() + ".typing",
            new TypingEvent(user.getUserId(), true)
        );
    }
    
    @MessageMapping("/typing.stop")
    public void handleTypingStop(@Payload TypingDTO typing, Principal principal) {
        UserPrincipal user = (UserPrincipal) principal;
        
        messagingTemplate.convertAndSend(
            "/topic/conversation." + typing.getConversationId() + ".typing",
            new TypingEvent(user.getUserId(), false)
        );
    }
}
```

#### 4. Presence System

```java
// realtime-gateway/src/main/java/.../gateway/service/PresenceService.java
@Service
@RequiredArgsConstructor
@Slf4j
public class PresenceService {
    
    private final RedisTemplate<String, String> redisTemplate;
    private final SimpMessagingTemplate messagingTemplate;
    
    private static final String PRESENCE_KEY_PREFIX = "presence:user:";
    private static final String ONLINE_USERS_KEY = "online:users";
    
    public void userConnected(UUID userId, String sessionId) {
        String key = PRESENCE_KEY_PREFIX + userId;
        
        // Store in Redis
        Map<String, String> presence = Map.of(
            "online", "true",
            "sessionId", sessionId,
            "lastSeen", LocalDateTime.now().toString()
        );
        
        redisTemplate.opsForHash().putAll(key, presence);
        redisTemplate.opsForSet().add(ONLINE_USERS_KEY, userId.toString());
        
        // Broadcast presence update
        broadcastPresenceUpdate(userId, true);
        
        log.info("User {} connected with session {}", userId, sessionId);
    }
    
    public void userDisconnected(UUID userId) {
        String key = PRESENCE_KEY_PREFIX + userId;
        
        // Update Redis
        redisTemplate.opsForHash().put(key, "online", "false");
        redisTemplate.opsForHash().put(key, "lastSeen", LocalDateTime.now().toString());
        redisTemplate.opsForSet().remove(ONLINE_USERS_KEY, userId.toString());
        
        // Broadcast presence update
        broadcastPresenceUpdate(userId, false);
        
        log.info("User {} disconnected", userId);
    }
    
    private void broadcastPresenceUpdate(UUID userId, boolean online) {
        PresenceEvent event = new PresenceEvent(userId, online, LocalDateTime.now());
        messagingTemplate.convertAndSend("/topic/presence", event);
    }
    
    public boolean isUserOnline(UUID userId) {
        String key = PRESENCE_KEY_PREFIX + userId;
        String online = (String) redisTemplate.opsForHash().get(key, "online");
        return "true".equals(online);
    }
}
```

#### 5. Connection Event Listener

```java
// realtime-gateway/src/main/java/.../gateway/listener/WebSocketEventListener.java
@Component
@RequiredArgsConstructor
@Slf4j
public class WebSocketEventListener {
    
    private final PresenceService presenceService;
    
    @EventListener
    public void handleWebSocketConnectListener(SessionConnectedEvent event) {
        StompHeaderAccessor headerAccessor = StompHeaderAccessor.wrap(event.getMessage());
        UserPrincipal user = (UserPrincipal) headerAccessor.getUser();
        String sessionId = headerAccessor.getSessionId();
        
        if (user != null) {
            presenceService.userConnected(user.getUserId(), sessionId);
        }
    }
    
    @EventListener
    public void handleWebSocketDisconnectListener(SessionDisconnectEvent event) {
        StompHeaderAccessor headerAccessor = StompHeaderAccessor.wrap(event.getMessage());
        UserPrincipal user = (UserPrincipal) headerAccessor.getUser();
        
        if (user != null) {
            presenceService.userDisconnected(user.getUserId());
        }
    }
}
```

---

## 📤 Week 2-3: media-service

### Day 6-7: Create Module

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

    <artifactId>media-service</artifactId>

    <dependencies>
        <!-- Internal -->
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-security</artifactId>
        </dependency>
        
        <!-- Spring Boot -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        
        <!-- Cloudinary -->
        <dependency>
            <groupId>com.cloudinary</groupId>
            <artifactId>cloudinary-http44</artifactId>
        </dependency>
        
        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Day 8-10: Cloudinary Integration

#### 1. Cloudinary Configuration

```java
// media-service/src/main/java/.../media/config/CloudinaryConfig.java
@Configuration
public class CloudinaryConfig {
    
    @Value("${cloudinary.cloud-name}")
    private String cloudName;
    
    @Value("${cloudinary.api-key}")
    private String apiKey;
    
    @Value("${cloudinary.api-secret}")
    private String apiSecret;
    
    @Bean
    public Cloudinary cloudinary() {
        return new Cloudinary(ObjectUtils.asMap(
            "cloud_name", cloudName,
            "api_key", apiKey,
            "api_secret", apiSecret,
            "secure", true
        ));
    }
}
```

**application.yml**:
```yaml
server:
  port: 8083

spring:
  application:
    name: media-service
  
  datasource:
    url: jdbc:postgresql://localhost:5432/ott_zalo
    username: postgres
    password: postgres
  
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        default_schema: media

  servlet:
    multipart:
      max-file-size: 100MB
      max-request-size: 100MB

cloudinary:
  cloud-name: ${CLOUDINARY_CLOUD_NAME}
  api-key: ${CLOUDINARY_API_KEY}
  api-secret: ${CLOUDINARY_API_SECRET}
```

#### 2. Media Entity

```java
// media-service/src/main/java/.../media/entity/MediaMetadata.java
@Entity
@Table(name = "media_metadata", schema = "media")
@Getter
@Setter
public class MediaMetadata extends BaseEntity {
    
    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "media_type", length = 20, nullable = false)
    private MediaType mediaType;  // IMAGE, VIDEO, DOCUMENT, AUDIO
    
    @Column(name = "mime_type", length = 100, nullable = false)
    private String mimeType;
    
    @Column(name = "original_filename")
    private String originalFilename;
    
    @Column(name = "cloudinary_public_id", length = 500, nullable = false)
    private String cloudinaryPublicId;
    
    @Column(name = "cloudinary_url", columnDefinition = "TEXT", nullable = false)
    private String cloudinaryUrl;
    
    @Column(name = "cloudinary_version", length = 20)
    private String cloudinaryVersion;
    
    @Column(name = "size_bytes")
    private Long sizeBytes;
    
    @Column(name = "width")
    private Integer width;
    
    @Column(name = "height")
    private Integer height;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20)
    private MediaStatus status = MediaStatus.READY;  // UPLOADING, READY, FAILED, DELETED
}
```

#### 3. Upload Service

```java
// media-service/src/main/java/.../media/service/MediaUploadService.java
@Service
@RequiredArgsConstructor
@Slf4j
public class MediaUploadService {
    
    private final Cloudinary cloudinary;
    private final MediaMetadataRepository mediaRepository;
    
    public MediaMetadata uploadImage(MultipartFile file, UUID userId) throws IOException {
        // Validate file
        validateImage(file);
        
        // Prepare upload params
        Map<String, Object> params = ObjectUtils.asMap(
            "folder", "chat",
            "resource_type", "image",
            "transformation", new Transformation()
                .width(1200)
                .quality("auto")
                .fetchFormat("webp")
        );
        
        // Upload to Cloudinary
        Map uploadResult = cloudinary.uploader().upload(file.getBytes(), params);
        
        // Save metadata
        MediaMetadata media = new MediaMetadata();
        media.setOwnerUserId(userId);
        media.setMediaType(MediaType.IMAGE);
        media.setMimeType(file.getContentType());
        media.setOriginalFilename(file.getOriginalFilename());
        media.setCloudinaryPublicId((String) uploadResult.get("public_id"));
        media.setCloudinaryUrl((String) uploadResult.get("secure_url"));
        media.setCloudinaryVersion(uploadResult.get("version").toString());
        media.setSizeBytes(((Number) uploadResult.get("bytes")).longValue());
        media.setWidth((Integer) uploadResult.get("width"));
        media.setHeight((Integer) upload Result.get("height"));
        media.setStatus(MediaStatus.READY);
        
        mediaRepository.save(media);
        
        log.info("Uploaded image {} for user {}", media.getId(), userId);
        return media;
    }
    
    private void validateImage(MultipartFile file) {
        // Check size (max 10MB)
        if (file.getSize() > 10 * 1024 * 1024) {
            throw new InvalidFileException("File size exceeds 10MB");
        }
        
        // Check type
        String contentType = file.getContentType();
        if (!contentType.startsWith("image/")) {
            throw new InvalidFileException("Only image files are allowed");
        }
    }
}
```

#### 4. Controller

```java
// media-service/src/main/java/.../media/controller/MediaController.java
@RestController
@RequestMapping("/api/v1/media")
@RequiredArgsConstructor
public class MediaController {
    
    private final MediaUploadService uploadService;
    
    @PostMapping("/upload/image")
    public ResponseEntity<MediaResponse> uploadImage(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal user) throws IOException {
        
        MediaMetadata media = uploadService.uploadImage(file, user.getUserId());
        return ResponseEntity.ok(MediaResponse.from(media));
    }
}
```

---

## 📝 Testing Your Work

### Test realtime-gateway

```javascript
// Use SockJS client
const socket = new SockJS('http://localhost:8085/ws');
const stompClient = Stomp.over(socket);

stompClient.connect(
  {'Authorization': 'Bearer YOUR_JWT_TOKEN'},
  function(frame) {
    console.log('Connected: ' + frame);
    
    // Subscribe to messages
    stompClient.subscribe('/topic/conversation.YOUR_CONV_ID', function(message) {
      console.log('Received:', JSON.parse(message.body));
    });
    
    // Send message
    stompClient.send('/app/message.send', {}, JSON.stringify({
      conversationId: 'YOUR_CONV_ID',
      content: 'Hello WebSocket!'
    }));
  }
);
```

### Test media-service

```bash
# Upload image
curl -X POST http://localhost:8083/api/v1/media/upload/image \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/path/to/image.jpg"
```

---

## ✅ Checklist

### Week 1-2: Realtime Gateway
- [ ] Create realtime-gateway module
- [ ] Configure WebSocket
- [ ] Implement JWT authentication for WS
- [ ] Implement message broadcasting
- [ ] Implement typing indicators
- [ ] Implement presence system (Redis)
- [ ] Test with multiple clients
- [ ] Integration test with messaging-service

### Week 2-3: Media Service
- [ ] Sign up Cloudinary
- [ ] Create media-service module
- [ ] Configure Cloudinary SDK
- [ ] Implement upload service (image)
- [ ] Implement upload service (video)
- [ ] Create media metadata tables
- [ ] Test upload API
- [ ] Test retrieval

---

*Continue to Week 4 for sticker implementation and optimization*
