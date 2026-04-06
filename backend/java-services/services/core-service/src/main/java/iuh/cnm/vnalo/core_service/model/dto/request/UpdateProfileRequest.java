package iuh.cnm.vnalo.core_service.model.dto.request;

import com.fasterxml.jackson.annotation.JsonAlias;
import iuh.cnm.vnalo.core_service.model.enums.Gender;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/**
 * DTO for updating user profile.
 */
public record UpdateProfileRequest(
        @JsonAlias("display_name")
        @Size(min = 2, max = 100, message = "Display name must be between 2 and 100 characters")
        @Pattern(regexp = "^(?!.*\\d).+$", message = "Display name must not contain numbers")
        String displayName,

        @JsonAlias("avatar_url")
        @Size(max = 500, message = "Avatar URL must not exceed 500 characters")
        String avatarUrl,

        @JsonAlias("cover_url")
        @Size(max = 500, message = "Cover URL must not exceed 500 characters")
        String coverUrl,

        @Size(max = 500, message = "Bio must not exceed 500 characters")
        String bio,

        Gender gender,

        LocalDate dob,

        @JsonAlias("status_message")
        @Size(max = 200, message = "Status message must not exceed 200 characters")
        String statusMessage
) {}
