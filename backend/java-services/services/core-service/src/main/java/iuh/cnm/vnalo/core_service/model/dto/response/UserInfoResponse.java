package iuh.cnm.vnalo.core_service.model.dto.response;

import iuh.cnm.vnalo.core_service.model.enums.Gender;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserInfoResponse {
    private UUID id;
    private String phone;
    private String displayName;
    private String avatarUrl;
    private String coverUrl;
    private String bio;
    private Gender gender;
    private LocalDate dob;
    private String statusMessage;
    private Boolean isVerified;
}
