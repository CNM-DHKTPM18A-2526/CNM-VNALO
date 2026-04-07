package iuh.cnm.vnalo.mediaservice.config;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaObject;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaStatus;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaObjectRepository;
import iuh.cnm.vnalo.mediaservice.service.S3Service;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * DataSeeder — downloads sample files from public CDN and uploads to S3.
 * Runs only with @Profile("dev"), skips if DB already has data.
 * Seeds 10 real files per MediaCategory (8 categories = 80 total).
 */
@Component
@Profile("dev")
@RequiredArgsConstructor
@Slf4j
public class DataSeeder implements ApplicationRunner {

    private final MediaObjectRepository mediaObjectRepository;
    private final S3Service s3Service;

    private static final UUID USER_1 = UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final UUID USER_2 = UUID.fromString("22222222-2222-2222-2222-222222222222");
    private static final UUID USER_3 = UUID.fromString("33333333-3333-3333-3333-333333333333");
    private static final UUID[] USERS = {USER_1, USER_2, USER_3};

    private static final int SEED_COUNT = 10;

    // -----------------------------------------------------------------------
    // Seed definitions: each entry = (sourceUrl, mimeType, ext, w, h, dur_ms)
    // Images: picsum.photos (random beautiful photos, always available)
    // Audio:  small OGG from Wikimedia (public domain)
    // Video:  small MP4 clip from sample-videos.com
    // PDF:    W3C sample PDF
    // -----------------------------------------------------------------------

    @Override
    public void run(ApplicationArguments args) {
        long count = mediaObjectRepository.count();
        if (count > 0) {
            log.info("DataSeeder: skipping — {} records already exist", count);
            return;
        }

        log.info("DataSeeder: starting S3 seed ({} categories × {} files)...", 8, SEED_COUNT);

        HttpClient http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .followRedirects(HttpClient.Redirect.ALWAYS)
                .build();

        List<MediaObject> saved = new ArrayList<>();

        saved.addAll(seedImages(http, MediaCategory.AVATAR,     400,  400));
        saved.addAll(seedImages(http, MediaCategory.COVER,      1920, 640));
        saved.addAll(seedImages(http, MediaCategory.CHAT_IMAGE, 800,  600));
        saved.addAll(seedImages(http, MediaCategory.STORY,      1080, 1920));
        saved.addAll(seedImages(http, MediaCategory.TIMELINE,   1200, 630));
        saved.addAll(seedAudio (http, MediaCategory.CHAT_VOICE));
        saved.addAll(seedPdfs  (http, MediaCategory.CHAT_FILE));
        saved.addAll(seedVideos(http, MediaCategory.CHAT_VIDEO));

        mediaObjectRepository.saveAll(saved);
        log.info("DataSeeder: completed — {} records seeded", saved.size());
    }

    // --- IMAGE: picsum.photos generates unique image per seed ID ------------

    private List<MediaObject> seedImages(HttpClient http, MediaCategory category, int w, int h) {
        List<MediaObject> list = new ArrayList<>();
        String folder = folder(category);

        for (int i = 1; i <= SEED_COUNT; i++) {
            // picsum.photos/seed/{n}/{w}/{h} — always returns the same image for same seed
            String sourceUrl = String.format("https://picsum.photos/seed/%s-%d/%d/%d", folder, i, w, h);
            String objectKey = String.format("demo/%s/sample-%02d.jpg", folder, i);

            try {
                byte[] bytes = download(http, sourceUrl);
                String url = s3Service.uploadBytes(bytes, objectKey, "image/jpeg");
                log.debug("Uploaded {}", objectKey);

                list.add(buildRecord(category, objectKey, url, "image/jpeg",
                        (long) bytes.length, w, h, null, i,
                        String.format("sample-%02d.jpg", i)));
            } catch (Exception e) {
                log.warn("DataSeeder: skipped {} ({})", objectKey, e.getMessage());
            }
        }
        return list;
    }

    // --- AUDIO: small OGG from Wikimedia ------------------------------------

    private List<MediaObject> seedAudio(HttpClient http, MediaCategory category) {
        List<MediaObject> list = new ArrayList<>();
        String folder = folder(category);

        // Public domain OGG clips from Wikimedia
        String[] sources = {
            "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/2b/Beethoven_Symphony_No._5_in_C_minor%2C_Op._67%2C_1st_movement%2C_bars_1-21.ogg/Beethoven_Symphony_No._5_in_C_minor%2C_Op._67%2C_1st_movement%2C_bars_1-21.ogg.mp3",
            "https://upload.wikimedia.org/wikipedia/commons/3/3a/Short_audio_sample.ogg"
        };

        for (int i = 1; i <= SEED_COUNT; i++) {
            String sourceUrl = sources[(i - 1) % sources.length];
            String objectKey = String.format("demo/%s/sample-%02d.ogg", folder, i);

            try {
                byte[] bytes = download(http, sourceUrl);
                String url = s3Service.uploadBytes(bytes, objectKey, "audio/ogg");
                log.debug("Uploaded {}", objectKey);

                list.add(buildRecord(category, objectKey, url, "audio/ogg",
                        (long) bytes.length, null, null, 15_000, i,
                        String.format("voice-message-%02d.ogg", i)));
            } catch (Exception e) {
                log.warn("DataSeeder: skipped {} ({})", objectKey, e.getMessage());
                // fallback: DB record only, no S3 file
                String fallbackUrl = s3Service.getFileUrl(objectKey);
                list.add(buildRecord(category, objectKey, fallbackUrl, "audio/ogg",
                        262_144L, null, null, 15_000, i,
                        String.format("voice-message-%02d.ogg", i)));
            }
        }
        return list;
    }

    // --- PDF: W3C sample PDF (small, ~10KB) ---------------------------------

    private List<MediaObject> seedPdfs(HttpClient http, MediaCategory category) {
        List<MediaObject> list = new ArrayList<>();
        String folder = folder(category);
        String sourceUrl = "https://www.w3.org/WAI/WCAG21/Techniques/pdf/W3C_Sample.pdf";

        for (int i = 1; i <= SEED_COUNT; i++) {
            String objectKey = String.format("demo/%s/sample-%02d.pdf", folder, i);
            try {
                byte[] bytes = download(http, sourceUrl);
                String url = s3Service.uploadBytes(bytes, objectKey, "application/pdf");
                log.debug("Uploaded {}", objectKey);

                list.add(buildRecord(category, objectKey, url, "application/pdf",
                        (long) bytes.length, null, null, null, i,
                        String.format("document-%02d.pdf", i)));
            } catch (Exception e) {
                log.warn("DataSeeder: skipped {} ({})", objectKey, e.getMessage());
                String fallbackUrl = s3Service.getFileUrl(objectKey);
                list.add(buildRecord(category, objectKey, fallbackUrl, "application/pdf",
                        102_400L, null, null, null, i,
                        String.format("document-%02d.pdf", i)));
            }
        }
        return list;
    }

    // --- VIDEO: small MP4 samples, tất cả < 5MB ---------------------------
    // Rotate qua 5 nguồn để tạo 10 S3 object khác nhau

    private static final String[] VIDEO_SOURCES = {
        // 1.5MB - file-examples.com (stable, explicitly sized)
        "https://file-examples.com/storage/fec42edfc96372ff7d3e958/2017/04/file_example_MP4_480_1_5MG.mp4",
        // 3MB - file-examples.com
        "https://file-examples.com/storage/fec42edfc96372ff7d3e958/2017/04/file_example_MP4_640_3MG.mp4",
        // ~1.2MB - W3Schools Big Buck Bunny clip (rất ổn định)
        "https://www.w3schools.com/html/mov_bbb.mp4",
        // 1MB - Big Buck Bunny 240p (sample-videos.com)
        "https://sample-videos.com/video321/mp4/240/big_buck_bunny_240p_1mb.mp4",
        // 2MB - Big Buck Bunny 360p (sample-videos.com)
        "https://sample-videos.com/video321/mp4/360/big_buck_bunny_360p_2mb.mp4"
    };

    private List<MediaObject> seedVideos(HttpClient http, MediaCategory category) {
        List<MediaObject> list = new ArrayList<>();
        String folder = folder(category);

        for (int i = 1; i <= SEED_COUNT; i++) {
            // Rotate qua 5 nguồn → 10 object S3 khác nhau
            String sourceUrl = VIDEO_SOURCES[(i - 1) % VIDEO_SOURCES.length];
            String objectKey = String.format("demo/%s/sample-%02d.mp4", folder, i);
            try {
                byte[] bytes = download(http, sourceUrl);
                String url = s3Service.uploadBytes(bytes, objectKey, "video/mp4");
                log.debug("Uploaded {} ({} KB)", objectKey, bytes.length / 1024);

                list.add(buildRecord(category, objectKey, url, "video/mp4",
                        (long) bytes.length, 640, 480, 30_000, i,
                        String.format("video-%02d.mp4", i)));
            } catch (Exception e) {
                log.warn("DataSeeder: skipped {} ({})", objectKey, e.getMessage());
                String fallbackUrl = s3Service.getFileUrl(objectKey);
                list.add(buildRecord(category, objectKey, fallbackUrl, "video/mp4",
                        3_145_728L, 640, 480, 30_000, i,
                        String.format("video-%02d.mp4", i)));
            }
        }
        return list;
    }

    // --- Helpers ------------------------------------------------------------

    private byte[] download(HttpClient http, String url) throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofSeconds(30))
                .GET()
                .build();
        HttpResponse<byte[]> response = http.send(request, HttpResponse.BodyHandlers.ofByteArray());
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new RuntimeException("HTTP " + response.statusCode() + " from " + url);
        }
        return response.body();
    }

    private MediaObject buildRecord(
            MediaCategory category, String objectKey, String url,
            String mimeType, long sizeBytes,
            Integer width, Integer height, Integer durationMs,
            int index, String filename) {

        UUID owner = USERS[(index - 1) % USERS.length];
        return MediaObject.builder()
                .ownerUserId(owner)
                .bucket(s3Service.getBucketName())
                .objectKey(objectKey)
                .url(url)
                .mimeType(mimeType)
                .sizeBytes(sizeBytes)
                .width(width)
                .height(height)
                .durationMs(durationMs)
                .originalFilename(filename)
                .mediaCategory(category)
                .status(MediaStatus.READY)
                .build();
    }

    private String folder(MediaCategory category) {
        return category.name().toLowerCase().replace("_", "-");
    }
}
