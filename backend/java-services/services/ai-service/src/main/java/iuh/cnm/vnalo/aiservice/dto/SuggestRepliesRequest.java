package iuh.cnm.vnalo.aiservice.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.Data;
import java.util.List;

@Data
public class SuggestRepliesRequest {

    @NotEmpty(message = "Lịch sử tin nhắn không được để trống")
    @Size(max = 10, message = "Lịch sử tin nhắn tối đa 10 tin")
    private List<Message> history;
}
