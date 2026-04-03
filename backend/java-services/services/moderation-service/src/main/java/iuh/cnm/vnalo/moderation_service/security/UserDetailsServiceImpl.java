package iuh.cnm.vnalo.moderation_service.security;

import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAdminUser;
import iuh.cnm.vnalo.moderation_service.repository.ModerationAdminUserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserDetailsServiceImpl implements UserDetailsService {

    private final ModerationAdminUserRepository moderationAdminUserRepository;

    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // Assuming username is userId as UUID string
        ModerationAdminUser adminUser = moderationAdminUserRepository.findByUserIdAndIsActiveTrue(UUID.fromString(username))
                .orElseThrow(() -> new UsernameNotFoundException("Admin user not found: " + username));
        return ModerationPrincipal.create(adminUser);
    }

    @Transactional(readOnly = true)
    public UserDetails loadUserById(String userId) {
        ModerationAdminUser adminUser = moderationAdminUserRepository.findByUserIdAndIsActiveTrue(UUID.fromString(userId))
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
        return ModerationPrincipal.create(adminUser);
    }
}