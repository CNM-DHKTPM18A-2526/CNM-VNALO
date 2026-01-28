# Developer 4 Guide - Moderation & Analytics Services (Mid-Level)

> **Your Services**: moderation-service, analytics-service  
> **Complexity**: 🟢 Low-Medium  
> **Estimated LOC**: 3,000  
> **Timeline**: Week 3-5

---

## 🎯 Your Responsibilities

You are the **Support & Admin Tools Owner**. Your work enables content moderation and system monitoring.

### Services Overview

1. **moderation-service** (Week 3-4)
   - Report management
   - Admin review panel
   - Automated actions

2. **analytics-service** (Week 4-5)
   - Activity logging
   - Stats tracking
   - Backup jobs

---

## 📦 Week 3-4: moderation-service

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

    <artifactId>moderation-service</artifactId>

    <dependencies>
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-security</artifactId>
        </dependency>
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-messaging</artifactId>
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
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-amqp</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Day 2-7: Report System

#### 1. Content Report Entity

```java
// moderation-service/src/main/java/.../moderation/entity/ContentReport.java
@Entity
@Table(name = "content_report", schema = "moderation")
@Getter
@Setter
public class ContentReport extends BaseEntity {
    
    @Column(name = "reporter_user_id", nullable = false)
    private UUID reporterUserId;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "target_type", length = 20, nullable = false)
    private ReportTargetType targetType;  // MEDIA, STICKER, TIMELINE, MESSAGE
    
    @Column(name = "target_id", nullable = false)
    private UUID targetId;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "reason_code", length = 30, nullable = false)
    private ReportReasonCode reasonCode;  // SPAM, HARASSMENT, INAPPROPRIATE, etc.
    
    @Column(name = "description", columnDefinition = "TEXT")
    private String description;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20)
    private ReportStatus status = ReportStatus.NEW;  // NEW, IN_REVIEW, RESOLVED
    
    @Column(name = "reviewed_by")
    private UUID reviewedBy;
    
    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;
}
```

#### 2. Report Service

```java
// moderation-service/src/main/java/.../moderation/service/ReportService.java
@Service
@RequiredArgsConstructor
@Transactional
public class ReportService {
    
    private final ContentReportRepository reportRepository;
    private final ModerationDecisionRepository decisionRepository;
    private final RabbitTemplate rabbitTemplate;
    
    public ContentReport submitReport(SubmitReportRequest request, UUID reporterUserId) {
        ContentReport report = new ContentReport();
        report.setReporterUserId(reporterUserId);
        report.setTargetType(request.getTargetType());
        report.setTargetId(request.getTargetId());
        report.setReasonCode(request.getReasonCode());
        report.setDescription(request.getDescription());
        report.setStatus(ReportStatus.NEW);
        
        return reportRepository.save(report);
    }
    
    public Page<ContentReport> getPendingReports(Pageable pageable) {
        return reportRepository.findByStatus(ReportStatus.NEW, pageable);
    }
    
    @PreAuthorize("hasRole('ADMIN')")
    public ModerationDecision reviewReport(UUID reportId, ReviewDecisionRequest request, UUID adminId) {
        ContentReport report = reportRepository.findById(reportId)
            .orElseThrow(() -> new ReportNotFoundException("Report not found"));
        
        // Create decision
        ModerationDecision decision = new ModerationDecision();
        decision.setReportId(reportId);
        decision.setDecidedBy(adminId);
        decision.setDecisionType(request.getDecisionType());
        decision.setNotes(request.getNotes());
        decisionRepository.save(decision);
        
        // Update report status
        report.setStatus(ReportStatus.RESOLVED);
        report.setReviewedBy(adminId);
        report.setReviewedAt(LocalDateTime.now());
        reportRepository.save(report);
        
        // Execute action if needed
        if (request.getDecisionType() != DecisionType.NO_ACTION) {
            executeAction(decision, report);
        }
        
        return decision;
    }
    
    private void executeAction(ModerationDecision decision, ContentReport report) {
        ModerationActionEvent event = new ModerationActionEvent(
            decision.getId(),
            report.getTargetType(),
            report.getTargetId(),
            decision.getDecisionType()
        );
        
        // Publish to RabbitMQ
        String routingKey = getRoutingKeyForTargetType(report.getTargetType());
        rabbitTemplate.convertAndSend("moderation.actions", routingKey, event);
    }
    
    private String getRoutingKeyForTargetType(ReportTargetType targetType) {
        return switch (targetType) {
            case MEDIA -> "media.action";
            case TIMELINE -> "content.action";
            case MESSAGE -> "message.action";
            default -> "default.action";
        };
    }
}
```

#### 3. Admin Controller

```java
// moderation-service/src/main/java/.../moderation/controller/AdminReportController.java
@RestController
@RequestMapping("/api/v1/admin/reports")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminReportController {
    
    private final ReportService reportService;
    
    @GetMapping("/pending")
    public ResponseEntity<Page<ReportDTO>> getPendingReports(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        
        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        Page<ContentReport> reports = reportService.getPendingReports(pageable);
        
        return ResponseEntity.ok(reports.map(ReportDTO::from));
    }
    
    @PostMapping("/{reportId}/review")
    public ResponseEntity<DecisionDTO> reviewReport(
            @PathVariable UUID reportId,
            @Valid @RequestBody ReviewDecisionRequest request,
            @AuthenticationPrincipal UserPrincipal admin) {
        
        ModerationDecision decision = reportService.reviewReport(reportId, request, admin.getUserId());
        return ResponseEntity.ok(DecisionDTO.from(decision));
    }
}
```

---

## 📊 Week 4-5: analytics-service

### Day 1: Create Module

#### 1. Activity Log Entity

```java
// analytics-service/src/main/java/.../analytics/entity/ActivityLog.java
@Entity
@Table(name = "activity_log", schema = "analytics")
@Getter
@Setter
public class ActivityLog extends BaseEntity {
    
    @Column(name = "user_id")
    private UUID userId;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "action_type", length = 50, nullable = false)
    private ActionType actionType;  // LOGIN, LOGOUT, SEND_MESSAGE, etc.
    
    @Column(name = "target_type", length = 30)
    private String targetType;
    
    @Column(name = "target_id")
    private UUID targetId;
    
    @Column(name = "ip_address", length = 45)
    private String ipAddress;
    
    @Column(name = "device_id", length = 100)
    private String deviceId;
    
    @Column(name = "metadata", columnDefinition = "JSONB")
    private String metadata;
}
```

#### 2. Stats Service

```java
// analytics-service/src/main/java/.../analytics/service/StatsService.java
@Service
@RequiredArgsConstructor
public class StatsService {
    
    private final ActivityLogRepository activityLogRepository;
    private final DailyStatsRepository dailyStatsRepository;
    
    @Scheduled(cron = "0 0 1 * * *")  // Run at 1 AM daily
    public void calculateDailyStats() {
        LocalDate yesterday = LocalDate.now().minusDays(1);
        LocalDateTime startOfDay = yesterday.atStartOfDay();
        LocalDateTime endOfDay = yesterday.atTime(23, 59, 59);
        
        // Count active users
        long activeUsers = activityLogRepository.countDistinctUsersByDateRange(
            startOfDay, endOfDay
        );
        
        // Count messages sent
        long messagesSent = activityLogRepository.countByActionTypeAndDateRange(
            ActionType.SEND_MESSAGE, startOfDay, endOfDay
        );
        
        // Save stats
        DailyStats stats = new DailyStats();
        stats.setDate(yesterday);
        stats.setActiveUsers((int) activeUsers);
        stats.setMessagesSent((int) messagesSent);
        dailyStatsRepository.save(stats);
    }
    
    public Map<String, Object> getDashboardStats() {
        LocalDate today = LocalDate.now();
        DailyStats todayStats = dailyStatsRepository.findByDate(today)
            .orElse(new DailyStats());
        
        return Map.of(
            "today", todayStats,
            "last7Days", dailyStatsRepository.findLast7Days(),
            "last30Days", dailyStatsRepository.findLast30Days()
        );
    }
}
```

#### 3. Backup Service

```java
// analytics-service/src/main/java/.../analytics/service/BackupService.java
@Service
@Slf4j
public class BackupService {
    
    @Value("${backup.path}")
    private String backupPath;
    
    @Scheduled(cron = "0 0 2 * * *")  // Run at 2 AM daily
    public void performDatabaseBackup() {
        try {
            String timestamp = LocalDateTime.now().format(
                DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss")
            );
            String filename = String.format("backup_%s.sql", timestamp);
            String filePath = Paths.get(backupPath, filename).toString();
            
            // Execute pg_dump
            ProcessBuilder pb = new ProcessBuilder(
                "pg_dump",
                "-h", "localhost",
                "-U", "postgres",
                "-d", "ott_zalo",
                "-F", "c",
                "-f", filePath
            );
            
            Process process = pb.start();
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                log.info("Database backup successful: {}", filename);
            } else {
                log.error("Database backup failed with exit code: {}", exitCode);
            }
            
        } catch (Exception e) {
            log.error("Database backup error: {}", e.getMessage());
        }
    }
}
```

---

## 📝 Testing

### Test Moderation APIs

```bash
# Submit report
curl -X POST http://localhost:8087/api/v1/reports \
  -H "Authorization: Bearer USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "targetType": "TIMELINE",
    "targetId": "uuid-here",
    "reasonCode": "SPAM",
    "description": "This is spam content"
  }'

# Admin: Get pending reports
curl http://localhost:8087/api/v1/admin/reports/pending \
  -H "Authorization: Bearer ADMIN_JWT"

# Admin: Review report
curl -X POST http://localhost:8087/api/v1/admin/reports/{reportId}/review \
  -H "Authorization: Bearer ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "decisionType": "REMOVE",
    "notes": "Content removed for violating policies"
  }'
```

### Test Analytics APIs

```bash
# Get dashboard stats
curl http://localhost:8088/api/v1/analytics/dashboard \
  -H "Authorization: Bearer ADMIN_JWT"
```

---

## ✅ Checklist

### Moderation Service
- [ ] Create moderation-service module
- [ ] Implement ContentReport entity
- [ ] Implement report submission (user)
- [ ] Implement admin review panel
- [ ] Implement ModerationDecision
- [ ] Implement action execution via RabbitMQ
- [ ] Test report flow end-to-end
- [ ] Add admin authentication

### Analytics Service
- [ ] Create analytics-service module
- [ ] Implement ActivityLog entity
- [ ] Implement event logging
- [ ] Implement DailyStats calculation
- [ ] Implement scheduled job for stats
- [ ] Implement backup service
- [ ] Test stats dashboard
- [ ] Setup cron jobs

---

## 🎯 Additional Responsibilities

### CI/CD (Bonus Task)

Create `.github/workflows/ci.yml`:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up JDK 17
      uses: actions/setup-java@v3
      with:
        java-version: '17'
        distribution: 'temurin'
    
    - name: Build with Maven
      run: mvn clean install -DskipTests
    
    - name: Run Tests
      run: mvn test
```

### Documentation

- [ ] Update API documentation
- [ ] Create admin panel user guide
- [ ] Document backup/restore procedures
- [ ] Document monitoring setup

---

*Complete! Your services support the entire platform*
