package iuh.cnm.vnalo.mediaservice.config;

import iuh.cnm.vnalo.mediaservice.domain.model.*;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaMetadataRepository;
import iuh.cnm.vnalo.mediaservice.domain.repository.StickerPackRepository;
import iuh.cnm.vnalo.mediaservice.domain.repository.StickerRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.List;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class StickerDataSeeder implements CommandLineRunner {

    private final StickerPackRepository stickerPackRepository;
    private final StickerRepository stickerRepository;
    private final MediaMetadataRepository mediaMetadataRepository;

    // We use a fixed system UUID for seeded packs
    private final UUID SYSTEM_USER_ID = UUID.fromString("00000000-0000-0000-0000-000000000000");

    @Override
    public void run(String... args) throws Exception {
        if (stickerPackRepository.count() >= 7) {
            log.info("Enough sticker packs already exist. Skipping data seeder.");
            return;
        }

        log.info("Starting Sticker Data Seeding...");
        
        // --- Pack 1: Chó Cà Khịa ---
        seedPack(
            "Chó Cà Khịa", 
            "Những chú chó dễ thương và xéo xắt.",
            "https://media.tenor.com/images/154739fcce7ded26b8b80d0dfffa81df/tenor.gif",
            Arrays.asList(
                "https://media.tenor.com/images/154739fcce7ded26b8b80d0dfffa81df/tenor.gif",
                "https://media.tenor.com/images/96cdafda4d12c8ff6aae6506df1bf431/tenor.gif",
                "https://media.tenor.com/images/0c00ec0ea79a836881c1ced305140b91/tenor.gif",
                "https://media.tenor.com/images/e7e39efca43b17c8051df55c4d21df65/tenor.gif",
                "https://media.tenor.com/images/f90f23071661f00b2cbda25ac36d9361/tenor.gif"
            )
        );

        // --- Pack 2: Mèo Mập ---
        seedPack(
            "Mèo Mập", 
            "Mèo cute phô mai que",
            "https://media.tenor.com/images/a55aebebed5d1ba95e0cba0c9b6b7139/tenor.gif",
            Arrays.asList(
                "https://media.tenor.com/images/a55aebebed5d1ba95e0cba0c9b6b7139/tenor.gif",
                "https://media.tenor.com/images/9c336b9c9f6a5b0ddf587dcb4ca820f4/tenor.gif",
                "https://media.tenor.com/images/bc8de32857e4e1de1c49b6ce8dcb4c1f/tenor.gif",
                "https://media.tenor.com/images/6249fa6b677a28892dc479b122be2cae/tenor.gif"
            )
        );
        
        // --- Pack 3: Củ Hành Anime ---
        seedPack(
            "Củ Hành Dễ Thương", 
            "Meme củ hành Zalo kinh điển",
            "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Food/Onion.png", // Demo
            Arrays.asList(
                "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Food/Onion.png",
                "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Food/Garlic.png",
                "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Food/Potato.png",
                "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Food/Tomato.png"
            )
        );

        // --- Pack 4: Puss in Boots ---
        seedPack(
            "Puss in Boots", 
            "Chú mèo đi hia dễ thương",
            "https://media.tenor.com/images/3f2081604a441e88863116892e66cce0/tenor.gif",
            Arrays.asList(
                "https://media.tenor.com/images/3f2081604a441e88863116892e66cce0/tenor.gif",
                "https://media.tenor.com/images/847045b8e9982464731f50a86d2673a3/tenor.gif",
                "https://media.tenor.com/images/f38b29f79093864a787208764a886f38/tenor.gif"
            )
        );

        // --- Pack 5: Classic Zalo Emoji (Big) ---
        seedPack(
            "Zalo Classic", 
            "Biểu cảm kinh điển",
            "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Beaming%20Face%20with%20Smiling%20Eyes.png",
            Arrays.asList(
                "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Beaming%20Face%20with%20Smiling%20Eyes.png",
                "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Face%20with%20Tears%20of%20Joy.png",
                "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Rolling%20on%20the%20Floor%20Laughing.png",
                "https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Winking%20Face.png"
            )
        );

        // --- Pack 6: Funny Shark ---
        seedPack(
            "Cá Mập Hài Hước", 
            "Sharky đáng yêu",
            "https://media.tenor.com/images/e7e39efca43b17c8051df55c4d21df65/tenor.gif",
            Arrays.asList(
                "https://media.tenor.com/images/e7e39efca43b17c8051df55c4d21df65/tenor.gif",
                "https://media.tenor.com/images/c0a6b47ec4f877636e0d37e3d9370605/tenor.gif"
            )
        );

        // --- Pack 7: Shiba Dog ---
        seedPack(
            "Shiba Inu", 
            "Đại gia đình Shiba",
            "https://media.tenor.com/images/96cdafda4d12c8ff6aae6506df1bf431/tenor.gif",
            Arrays.asList(
                "https://media.tenor.com/images/96cdafda4d12c8ff6aae6506df1bf431/tenor.gif",
                "https://media.tenor.com/images/154739fcce7ded26b8b80d0dfffa81df/tenor.gif"
            )
        );

        log.info("Finished Sticker Data Seeding.");
    }

    private void seedPack(String name, String description, String coverUrl, List<String> stickerUrls) {
        // Create cover media
        MediaMetadata coverMedia = createMockMedia(coverUrl, name + " Cover");
        
        // Create Pack
        StickerPack pack = StickerPack.builder()
                .ownerUserId(SYSTEM_USER_ID)
                .name(name)
                .description(description)
                .coverMediaId(coverMedia.getId()) // Gắn media cover ID
                .stickerCount(stickerUrls.size())
                .status(StickerPackStatus.PUBLISHED)
                .downloadCount(0)
                .build();
        
        pack = stickerPackRepository.save(pack);

        // Add stickers
        int displayOrder = 0;
        for (String url : stickerUrls) {
            MediaMetadata sm = createMockMedia(url, "Sticker " + displayOrder);
            Sticker sticker = Sticker.builder()
                    .packId(pack.getStickerPackId())
                    .mediaId(sm.getId())
                    .name("Sticker " + displayOrder)
                    .isAnimated(url.endsWith(".gif"))
                    .displayOrder(displayOrder++)
                    .status(StickerStatus.ACTIVE)
                    .build();
            stickerRepository.save(sticker);
        }
    }

    private MediaMetadata createMockMedia(String url, String title) {
        MediaMetadata media = MediaMetadata.builder()
                .ownerUserId(SYSTEM_USER_ID)
                .bucket("vnalo-public-mocks")
                .objectKey(UUID.randomUUID().toString() + "-" + title)
                .url(url)
                .thumbnailUrl(url)
                .mimeType(url.endsWith(".gif") ? "image/gif" : "image/png")
                .sizeBytes(102400L) // 100KB mock
                .category(MediaCategory.STICKER)
                .status(MediaStatus.READY)
                .build();
        
        return mediaMetadataRepository.save(media);
    }
}
