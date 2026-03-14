package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.entity.social.ContactSync;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.ContactSyncService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST Controller for phone contact synchronization.
 * Allows users to sync their phone contacts and find registered VNALO users.
 */
@RestController
@RequestMapping("/contacts")
@RequiredArgsConstructor
@Tag(name = "Contacts", description = "Phone contact synchronization")
public class ContactSyncController {

    private final ContactSyncService contactSyncService;

    /**
     * Sync a batch of phone contacts.
     * Returns matched and unmatched contacts.
     */
    @PostMapping("/sync")
    @Operation(summary = "Sync phone contacts",
               description = "Upload phone contacts to find registered VNALO users")
    public ResponseEntity<ApiResponse<List<ContactSync>>> syncContacts(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody List<ContactSyncRequest> contacts) {

        List<ContactSyncService.ContactSyncRequest> serviceContacts = contacts.stream()
                .map(c -> new ContactSyncService.ContactSyncRequest(c.phoneNumber(), c.contactName()))
                .toList();

        List<ContactSync> results = contactSyncService.syncContacts(currentUser.getId(), serviceContacts);
        return ResponseEntity.ok(ApiResponse.success("Contacts synced", results));
    }

    /**
     * Get contacts that matched to registered users.
     */
    @GetMapping("/matched")
    @Operation(summary = "Get matched contacts",
               description = "Get phone contacts that are registered on VNALO")
    public ResponseEntity<ApiResponse<Page<ContactSync>>> getMatchedContacts(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PageableDefault(size = 20) Pageable pageable) {

        Page<ContactSync> contacts = contactSyncService.getMatchedContacts(currentUser.getId(), pageable);
        return ResponseEntity.ok(ApiResponse.success(contacts));
    }

    /**
     * Get all synced contacts.
     */
    @GetMapping
    @Operation(summary = "Get all synced contacts")
    public ResponseEntity<ApiResponse<Page<ContactSync>>> getAllContacts(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PageableDefault(size = 20) Pageable pageable) {

        Page<ContactSync> contacts = contactSyncService.getAllContacts(currentUser.getId(), pageable);
        return ResponseEntity.ok(ApiResponse.success(contacts));
    }

    /**
     * Clear all synced contacts.
     */
    @DeleteMapping
    @Operation(summary = "Clear all synced contacts")
    public ResponseEntity<ApiResponse<Void>> clearContacts(
            @AuthenticationPrincipal UserPrincipal currentUser) {

        contactSyncService.clearContacts(currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Contacts cleared"));
    }

    /**
     * Request body record for a single contact.
     */
    public record ContactSyncRequest(
            @NotBlank String phoneNumber,
            String contactName
    ) {}
}
