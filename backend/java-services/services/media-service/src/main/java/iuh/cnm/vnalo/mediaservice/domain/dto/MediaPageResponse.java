package iuh.cnm.vnalo.mediaservice.domain.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * DTO for paginated media listing response.
 */
@Data
@Builder
public class MediaPageResponse {
    private List<MediaResponse> content;
    private int page;
    private int size;
    private long totalElements;
    private int totalPages;
    private boolean last;
}
