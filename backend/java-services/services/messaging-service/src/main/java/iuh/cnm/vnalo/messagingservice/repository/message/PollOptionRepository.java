package iuh.cnm.vnalo.messagingservice.repository.message;

import iuh.cnm.vnalo.messagingservice.model.entity.PollOption;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PollOptionRepository extends JpaRepository<PollOption, UUID> {
    List<PollOption> findByPollIdOrderByOptionOrderAsc(UUID pollId);
}
