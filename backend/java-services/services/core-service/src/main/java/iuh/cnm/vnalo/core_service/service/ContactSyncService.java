package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.social.ContactSync;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.social.ContactSyncRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserPrivacySettingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Service for synchronizing phone contacts with registered users.
 * Allows users to find which of their phone contacts are on VNALO.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ContactSyncService {

    private final ContactSyncRepository contactSyncRepository;
    private final AuthAccountRepository authAccountRepository;
    private final UserPrivacySettingRepository userPrivacySettingRepository;

    /**
     * Sync a batch of phone contacts.
     * For each contact, check if the phone number belongs to a registered user.
     * Returns the list of contacts with match status.
     */
    @Transactional
    public List<ContactSync> syncContacts(UUID userId, List<ContactSyncRequest> contacts) {
        List<ContactSync> results = new ArrayList<>();

        for (ContactSyncRequest contact : contacts) {
            String normalizedPhone = normalizePhone(contact.phoneNumber());

            // Check if already synced
            ContactSync existing = contactSyncRepository
                    .findByUserIdAndPhoneNumber(userId, normalizedPhone)
                    .orElse(null);

            if (existing != null) {
                // Update contact name if changed
                if (contact.contactName() != null) {
                    existing.setContactName(contact.contactName());
                }
                // Re-check match (user might have registered since last sync)
                if (existing.getMatchedUserId() == null) {
                    matchContact(existing);
                }
                existing.setSyncedAt(Instant.now());
                results.add(contactSyncRepository.save(existing));
            } else {
                ContactSync newContact = ContactSync.builder()
                        .userId(userId)
                        .phoneNumber(normalizedPhone)
                        .contactName(contact.contactName())
                        .syncedAt(Instant.now())
                        .build();

                matchContact(newContact);
                results.add(contactSyncRepository.save(newContact));
            }
        }

        log.info("Synced {} contacts for user {}", results.size(), userId);
        return results;
    }

    /**
     * Get contacts that matched to registered users.
     */
    @Transactional(readOnly = true)
    public Page<ContactSync> getMatchedContacts(UUID userId, Pageable pageable) {
        return contactSyncRepository.findByUserIdAndMatchedUserIdIsNotNull(userId, pageable);
    }

    /**
     * Get all synced contacts for a user.
     */
    @Transactional(readOnly = true)
    public Page<ContactSync> getAllContacts(UUID userId, Pageable pageable) {
        return contactSyncRepository.findByUserId(userId, pageable);
    }

    /**
     * Delete all synced contacts for a user.
     */
    @Transactional
    public void clearContacts(UUID userId) {
        contactSyncRepository.deleteByUserId(userId);
        log.info("Cleared all synced contacts for user {}", userId);
    }

    // ─── Helpers ──────────────────────────────────────────

    private void matchContact(ContactSync contact) {
        authAccountRepository.findByPhone(contact.getPhoneNumber())
                .ifPresent(account -> {
                    // Don't match to self
                    if (!account.getId().equals(contact.getUserId())) {
                        final boolean allowSearchByPhone = userPrivacySettingRepository.findById(account.getId())
                                .map(setting -> Boolean.TRUE.equals(setting.getAllowSearchByPhone()))
                                .orElse(true);
                        if (allowSearchByPhone) {
                            contact.matchToUser(account.getId());
                        }
                    }
                });
    }

    private String normalizePhone(String phone) {
        if (phone == null) return "";
        // Remove all non-digit characters except leading +
        String cleaned = phone.replaceAll("[^+\\d]", "");
        // Convert 0xxx to +84xxx (Vietnam)
        if (cleaned.startsWith("0")) {
            cleaned = "+84" + cleaned.substring(1);
        }
        return cleaned;
    }

    /**
     * Request record for a single contact to sync.
     */
    public record ContactSyncRequest(String phoneNumber, String contactName) {}
}
