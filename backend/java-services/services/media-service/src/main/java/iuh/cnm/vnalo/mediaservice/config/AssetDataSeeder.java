package iuh.cnm.vnalo.mediaservice.config;

import iuh.cnm.vnalo.mediaservice.domain.model.*;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaMetadataRepository;
import iuh.cnm.vnalo.mediaservice.domain.repository.StickerPackRepository;
import iuh.cnm.vnalo.mediaservice.domain.repository.StickerRepository;
import iuh.cnm.vnalo.mediaservice.service.S3Service;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.io.File;
import java.nio.file.Files;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class AssetDataSeeder implements CommandLineRunner {

    private final MediaMetadataRepository mediaMetadataRepository;
    private final StickerPackRepository stickerPackRepository;
    private final StickerRepository stickerRepository;
    private final S3Service s3Service;

    // UUID cố định cho Hệ thống
    private static final UUID SYSTEM_USER_ID = UUID.fromString("00000000-0000-0000-0000-000000000000");

    @Value("${application.seeding.source-dir:/app/img}")
    private String sourceDir;

    @Override
    public void run(String... args) throws Exception {
        // 1. Kiểm tra xem đã seed đủ chưa
        boolean hasStickers = stickerPackRepository.findAll().stream()
                .anyMatch(p -> "vnalo sticker".equalsIgnoreCase(p.getName()));
        boolean hasGifs = !mediaMetadataRepository.findByCategory(MediaCategory.GIF, org.springframework.data.domain.Pageable.ofSize(1)).isEmpty();

        if (hasStickers && hasGifs) {
            log.info("AssetDataSeeder: Everything already seeded. Skipping.");
            return;
        }

        log.info("AssetDataSeeder: Starting seeding process (Stickers: {}, Gifs: {})...", hasStickers, hasGifs);


        File root = new File(sourceDir);
        if (!root.exists() || !root.isDirectory()) {
            log.error("AssetDataSeeder: Source directory not found at {}", sourceDir);
            return;
        }

        log.info("AssetDataSeeder: Starting global asset seeding from {}...", sourceDir);

        // 2. Xử lý Emojis
        seedFolder(new File(root, "emoji"), MediaCategory.EMOJI);

        // 3. Xử lý GIFs
        seedFolder(new File(root, "gif"), MediaCategory.GIF);

        // 4. Xử lý Stickers & Group vào Pack
        seedStickers(new File(root, "sticker"));

        log.info("AssetDataSeeder: Global asset seeding completed successfully!");
    }

    // Đã thay thế logic kiểm tra trực tiếp trong hàm run


    private void seedFolder(File folder, MediaCategory category) {
        if (!folder.exists() || !folder.isDirectory()) return;

        File[] files = folder.listFiles();
        if (files == null) return;

        for (File file : files) {
            if (file.isDirectory() || file.isHidden()) continue;
            try {
                uploadAndSaveMedia(file, category);
                log.info("Seeded {} asset: {}", category, file.getName());
            } catch (Exception e) {
                log.error("Failed to seed file: {}", file.getName(), e);
            }
        }
    }

    private void seedStickers(File folder) throws Exception {
        if (!folder.exists() || !folder.isDirectory()) return;

        File[] files = folder.listFiles();
        if (files == null || files.length == 0) return;

        // Tạo Sticker Pack mới
        StickerPack pack = StickerPack.builder()
                .ownerUserId(SYSTEM_USER_ID)
                .name("vnalo sticker")
                .description("Bộ sticker mặc định của hệ thống VNALO")
                .status(StickerPackStatus.PUBLISHED)
                .stickerCount(0)
                .downloadCount(0)
                .build();

        // Thiết lập ảnh nền (lấy file đầu tiên làm cover)
        MediaMetadata coverMedia = uploadAndSaveMedia(files[0], MediaCategory.STICKER);
        pack.setCoverMediaId(coverMedia.getId());
        pack = stickerPackRepository.save(pack);

        int displayOrder = 0;
        for (File file : files) {
            try {
                MediaMetadata mo = uploadAndSaveMedia(file, MediaCategory.STICKER);
                
                Sticker sticker = Sticker.builder()
                        .packId(pack.getStickerPackId())
                        .mediaId(mo.getId())
                        .name(file.getName().replaceFirst("[.][^.]+$", ""))
                        .isAnimated(file.getName().toLowerCase().endsWith(".gif"))
                        .displayOrder(displayOrder++)
                        .status(StickerStatus.ACTIVE)
                        .build();
                
                stickerRepository.save(sticker);
                pack.setStickerCount(pack.getStickerCount() + 1);
            } catch (Exception e) {
                log.error("Failed to seed sticker: {}", file.getName(), e);
            }
        }
        stickerPackRepository.save(pack);
        log.info("Seeded Sticker Pack 'vnalo sticker' with {} stickers", displayOrder);
    }

    private MediaMetadata uploadAndSaveMedia(File file, MediaCategory category) throws Exception {
        byte[] content = Files.readAllBytes(file.toPath());
        String extension = getFileExtension(file.getName());
        String contentType = extension.equalsIgnoreCase("gif") ? "image/gif" : "image/png";
        
        // Tạo object key: category/systemID/filename_uuid.ext
        String objectKey = String.format("%s/%s/%s_%s.%s", 
                category.name().toLowerCase(), 
                SYSTEM_USER_ID, 
                FilenameUtils_getBaseName(file.getName()),
                UUID.randomUUID().toString().substring(0, 8),
                extension);

        String url = s3Service.uploadBytes(content, objectKey, contentType);

        MediaMetadata media = MediaMetadata.builder()
                .ownerUserId(SYSTEM_USER_ID)
                .bucket(s3Service.getBucketName())
                .objectKey(objectKey)
                .url(url)
                .thumbnailUrl(url)
                .mimeType(contentType)
                .sizeBytes((long) content.length)
                .category(category)
                .originalFilename(file.getName())
                .status(MediaStatus.UPLOADED)
                .needsProcessing(false)
                .build();

        return mediaMetadataRepository.save(media);
    }

    private String getFileExtension(String fileName) {
        int lastIndex = fileName.lastIndexOf('.');
        return (lastIndex == -1) ? "" : fileName.substring(lastIndex + 1);
    }

    private String FilenameUtils_getBaseName(String fileName) {
        int dotIndex = fileName.lastIndexOf('.');
        return (dotIndex == -1) ? fileName : fileName.substring(0, dotIndex);
    }
}
