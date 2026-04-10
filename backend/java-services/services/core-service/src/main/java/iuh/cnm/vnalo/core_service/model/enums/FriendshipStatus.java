package iuh.cnm.vnalo.core_service.model.enums;

/**
 * Enum representing the friendship status between two users.
 */
public enum FriendshipStatus {
    /** No relationship exists between the users. */
    NONE,

    /** Users are currently friends. */
    FRIEND,

    /** Current user has sent a friend request to the other user. */
    PENDING_SENT,

    /** Other user has sent a friend request to the current user. */
    PENDING_RECEIVED,

    /** Current user has blocked the other user. */
    BLOCKED_BY_ME,

    /** Other user has blocked the current user. */
    BLOCKED_BY_THEM,

    /** Both users have blocked each other (rare). */
    BLOCKED_BOTH
}
