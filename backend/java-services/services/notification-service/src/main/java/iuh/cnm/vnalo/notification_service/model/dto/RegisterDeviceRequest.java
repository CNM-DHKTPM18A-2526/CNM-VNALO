package iuh.cnm.vnalo.notification_service.model.dto;

import lombok.Data;

@Data
public class RegisterDeviceRequest {
  private String deviceId;
  private String platform;
  private String fcmToken;
}
