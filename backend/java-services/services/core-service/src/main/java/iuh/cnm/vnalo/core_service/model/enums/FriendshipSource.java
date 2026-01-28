package iuh.cnm.vnalo.core_service.model.enums;

/**
 * Source of friendship connection.
 */
public enum FriendshipSource {
    /**
     * Found via search.
     */
    SEARCH,

    /**
     * Added via QR code scan.
     */
    QR,

    /**
     * Imported from phone contacts.
     */
    CONTACT_IMPORT,

    /**
     * System suggestion.
     */
    SUGGESTION,

    /**
     * Met through shared group.
     */
    GROUP
}
