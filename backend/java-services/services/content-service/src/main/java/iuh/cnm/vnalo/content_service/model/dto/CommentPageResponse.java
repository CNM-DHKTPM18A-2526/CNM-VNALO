package iuh.cnm.vnalo.content_service.model.dto;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
public class CommentPageResponse {

    private List<CommentResponse> items;
    private int page;
    private int size;
    private long totalElements;
    private int totalPages;
    private boolean last;
}