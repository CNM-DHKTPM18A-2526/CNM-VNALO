package iuh.cnm.vnalo.core_service.model.enums;

/**
 * Friend request status types.
 */
public enum FriendRequestStatus {
    /**
     * Waiting for recipient's response.
     */
    PENDING,

    /**
     * Request has been accepted.
     */
    ACCEPTED,

    /**
     * Request has been declined.
     */
    DECLINED,

    /**
     * Request has been canceled by sender.
     */
    CANCELED
}
