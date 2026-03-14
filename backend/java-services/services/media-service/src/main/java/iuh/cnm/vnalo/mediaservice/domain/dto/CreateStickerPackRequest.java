package iuh.cnm.vnalo.mediaservice.domain.dto;

import iuh.cnm.vnalo.mediaservice.domain.model.StickerPackCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class CreateStickerPackRequest {

    @NotBlank(message = "Tên pack không được để trống")
    @Size(max = 100, message = "Tên pack tối đa 100 ký tự")
    private String name;

    @Size(max = 500, message = "Mô tả tối đa 500 ký tự")
    private String description;

    @Size(max = 100)
    private String author;

    private StickerPackCategory category;

    private Boolean isPremium = false;

    private Boolean isAnimated = false;

    private BigDecimal price;
}
