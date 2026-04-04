package iuh.cnm.vnalo.notification_service.model.dto;

import com.fasterxml.jackson.databind.JsonNode;

import lombok.Data;

import java.util.UUID;

@Data
public class CreateNotificationRequest {
  private UUID userId;
  private String type;
  private String title;
  private String body;
  private JsonNode data;
}
