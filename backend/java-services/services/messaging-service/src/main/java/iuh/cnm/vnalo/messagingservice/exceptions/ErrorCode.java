package iuh.cnm.vnalo.messagingservice.exceptions;

import lombok.Getter;

@Getter
public enum ErrorCode {
    // General
    INTERNAL_ERROR("ERR_500", "Internal server error"),
    VALIDATION_ERROR("ERR_400", "Validation failed"),
    RESOURCE_NOT_FOUND("ERR_404", "Resource not found"),
    ACCESS_DENIED("ERR_403", "Access denied"),
    UNAUTHORIZED("ERR_401", "Unauthorized"),

    // Conversation
    CONV_NOT_FOUND("CONV_001", "Conversation not found"),
    CONV_ALREADY_EXISTS("CONV_002", "Conversation already exists"),
    CONV_NOT_MEMBER("CONV_003", "You are not a member of this conversation"),
    CONV_INSUFFICIENT_PERMISSION("CONV_004", "Insufficient permission for this operation"),
    CONV_MEMBER_LIMIT_REACHED("CONV_005", "Conversation member limit reached"),
    CONV_DIRECT_ALREADY_EXISTS("CONV_006", "Direct conversation already exists with this user"),
    CONV_CANNOT_LEAVE_OWNER("CONV_007", "Owner must transfer ownership before leaving"),
    CONV_USER_BANNED("CONV_008", "User is banned from this conversation"),
    CONV_USER_NOT_BANNED("CONV_009", "User is not banned from this conversation"),
    CONV_NOT_GROUP("CONV_010", "This operation is only available for group conversations"),
    CONV_JOIN_REQUEST_ALREADY_PENDING("CONV_011", "A join request is already pending for this conversation"),
    CONV_JOIN_REQUEST_NOT_FOUND("CONV_012", "Join request not found"),
    CONV_ALREADY_MEMBER("CONV_013", "User is already a member of this conversation"),

    // Message
    MSG_NOT_FOUND("MSG_001", "Message not found"),
    MSG_NOT_SENDER("MSG_002", "You are not the sender of this message"),
    MSG_ALREADY_DELETED("MSG_003", "Message has already been deleted"),
    MSG_ALREADY_PINNED("MSG_004", "Message is already pinned"),
    MSG_NOT_PINNED("MSG_005", "Message is not pinned"),

    // Reaction
    REACTION_ALREADY_EXISTS("REACT_001", "You have already reacted to this message"),
    REACTION_NOT_FOUND("REACT_002", "Reaction not found"),

    // Poll
    POLL_NOT_FOUND("POLL_001", "Poll not found"),
    POLL_ALREADY_CLOSED("POLL_002", "Poll is already closed"),
    POLL_ALREADY_VOTED("POLL_003", "You have already voted on this option"),
    POLL_OPTION_NOT_FOUND("POLL_004", "Poll option not found"),

    // Call
    CALL_NOT_FOUND("CALL_001", "Call not found"),
    CALL_ALREADY_ONGOING("CALL_002", "There is already an ongoing call in this conversation"),
    CALL_NOT_PARTICIPANT("CALL_003", "You are not a participant of this call"),
    CALL_ALREADY_ENDED("CALL_004", "Call has already ended"),
    CALL_USER_BUSY("CALL_005", "User is currently busy"),

    // Notification
    NOTIF_NOT_FOUND("NOTIF_001", "Notification not found"),
    NOTIF_DEVICE_TOKEN_EXISTS("NOTIF_002", "Device token already registered");

    private final String code;
    private final String message;

    ErrorCode(String code, String message) {
        this.code = code;
        this.message = message;
    }
}
