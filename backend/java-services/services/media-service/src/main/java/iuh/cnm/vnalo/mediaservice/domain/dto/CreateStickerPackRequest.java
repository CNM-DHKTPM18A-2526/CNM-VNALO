package iuh.cnm.vnalo.mediaservice.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.UUID;

@Data
public class CreateStickerPackRequest {

    @NotBlank(message = "Tên pack không được để trống")
    @Size(max = 100, message = "Tên pack tối đa 100 ký tự")
    private String name;

    @Size(max = 500, message = "Mô tả tối đa 500 ký tự")
    private String description;

    @NotNull(message = "Cover media ID không được để trống")
    private UUID coverMediaId;
}
