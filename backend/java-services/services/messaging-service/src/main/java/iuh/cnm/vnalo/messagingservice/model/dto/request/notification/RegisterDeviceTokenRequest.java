package iuh.cnm.vnalo.messagingservice.model.dto.request.notification;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class RegisterDeviceTokenRequest {

    @NotBlank(message = "Device ID is required")
    private String deviceId;

    @NotBlank(message = "Push token is required")
    private String pushToken;

    @NotNull(message = "Platform is required")
    private String platform;

    // Optional fields
    private String voipToken;
    private String appVersion;
    private String osVersion;
    private String deviceModel;
    private String deviceName;
}
