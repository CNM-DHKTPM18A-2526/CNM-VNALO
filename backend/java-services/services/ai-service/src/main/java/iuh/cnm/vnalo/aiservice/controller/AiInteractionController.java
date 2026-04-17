package iuh.cnm.vnalo.aiservice.controller;

import iuh.cnm.vnalo.aiservice.dto.request.AiChatRequest;
import iuh.cnm.vnalo.aiservice.dto.response.AiChatResponse;
import iuh.cnm.vnalo.aiservice.service.GeminiAiService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/api/v1/ai")
@RequiredArgsConstructor
public class AiInteractionController {

    private final GeminiAiService geminiAiService;

    @PostMapping("/chat")
    public ResponseEntity<Object> interactWithMascot(@Valid @RequestBody AiChatRequest request) {
        log.info("Received AI Command. Analyzing intent: {}", request.isAnalyzeIntent());
        
        try {
            AiChatResponse response = geminiAiService.interactWithGemini(request);
            return ResponseEntity.ok(response);
            
        } catch (RuntimeException e) {
            if ("QUOTA_EXCEEDED".equals(e.getMessage())) {
                return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                        .body("AI Assistant is currently overloaded. Please try again later.");
            }
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body("VNALO Brain is restarting.");
        }
    }
}
