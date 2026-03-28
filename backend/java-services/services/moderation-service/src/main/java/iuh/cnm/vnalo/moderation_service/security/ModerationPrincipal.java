package iuh.cnm.vnalo.moderation_service.security;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAdminUser;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public class ModerationPrincipal implements UserDetails {

    private final UUID id;
    private final String role;
    private final boolean active;
    private final Collection<? extends GrantedAuthority> authorities;

    public ModerationPrincipal(
            UUID id,
            String role,
            boolean active,
            Collection<? extends GrantedAuthority> authorities
    ) {
        this.id = id;
        this.role = role;
        this.active = active;
        this.authorities = authorities;
    }

    public static ModerationPrincipal create(ModerationAdminUser adminUser) {
        return new ModerationPrincipal(
                adminUser.getUserId(),
                adminUser.getRole().name(),
                Boolean.TRUE.equals(adminUser.getIsActive()),
                List.of(new SimpleGrantedAuthority("ROLE_" + adminUser.getRole().name()))
        );
    }

    public UUID getId() {
        return id;
    }

    public String getRoleName() {
        return role;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return authorities;
    }

    @Override
    public String getPassword() {
        return null;
    }

    @Override
    public String getUsername() {
        return id.toString();
    }

    @Override
    public boolean isAccountNonExpired() {
        return active;
    }

    @Override
    public boolean isAccountNonLocked() {
        return active;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return active;
    }

    @Override
    public boolean isEnabled() {
        return active;
    }
}