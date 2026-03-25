package iuh.cnm.vnalo.moderation_service.service;

import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateAdminUserRequest;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAdminUser;
import iuh.cnm.vnalo.moderation_service.repository.ModerationAdminUserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AdminUserService {
    private final ModerationAdminUserRepository adminUserRepository;

    @Transactional
    public void createAdminUser(CreateAdminUserRequest request) {
        ModerationAdminUser adminUser = ModerationAdminUser.builder()
                .userId(request.getUserId())
                .role(request.getRole())
                .isActive(true)
                .build();
        adminUserRepository.save(adminUser);
    }
}