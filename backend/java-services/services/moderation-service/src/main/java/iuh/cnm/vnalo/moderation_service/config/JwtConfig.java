package iuh.cnm.vnalo.moderation_service.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "jwt")
@Getter
@Setter
public class JwtConfig {
    private String secret;
    private String issuer;
    private long accessTokenExpiration;
    private long refreshTokenExpiration;

    public long getAccessTokenExpirationSeconds() {
        return accessTokenExpiration / 1000;
    }
}