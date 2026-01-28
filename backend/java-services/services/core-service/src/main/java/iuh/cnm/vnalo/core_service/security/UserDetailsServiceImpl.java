package iuh.cnm.vnalo.core_service.security;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
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

    private final AuthAccountRepository authAccountRepository;

    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String phone) throws UsernameNotFoundException {
        AuthAccount account = authAccountRepository.findByPhone(phone)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + phone));
        return UserPrincipal.create(account);
    }

    @Transactional(readOnly = true)
    public UserDetails loadUserById(String userId) {
        AuthAccount account = authAccountRepository.findById(UUID.fromString(userId))
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));
        return UserPrincipal.create(account);
    }
}
