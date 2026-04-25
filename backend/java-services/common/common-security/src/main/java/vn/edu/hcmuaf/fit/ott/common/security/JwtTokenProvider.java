package vn.edu.hcmuaf.fit.ott.common.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import io.jsonwebtoken.security.SignatureException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

/**
 * JWT Token Provider for generating and validating JWT tokens (Modern 0.12.x)
 */
@Component
@Slf4j
public class JwtTokenProvider {

    @Value("${jwt.secret:your-very-long-secret-key-at-least-512-bits-for-hs512-algorithm}")
    private String jwtSecret;

    @Value("${jwt.expiration:86400000}") // 1 day
    private long jwtExpiration;

    private SecretKey secretKey;

    @PostConstruct
    public void init() {
        try {
            byte[] keyBytes = Decoders.BASE64.decode(jwtSecret);
            this.secretKey = Keys.hmacShaKeyFor(keyBytes);
        } catch (Exception e) {
            log.warn("JWT secret is not Base64 encoded, using plain bytes. Recommendation: Use Base64 for HS512.");
            this.secretKey = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        }
    }

    /**
     * Generate JWT access token
     */
    public String generateAccessToken(UUID userId) {
        Instant now = Instant.now();
        Instant expiry = now.plusMillis(jwtExpiration);

        return Jwts.builder()
                .subject(userId.toString())
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiry))
                .signWith(secretKey, Jwts.SIG.HS512)
                .compact();
    }

    /**
     * Get user ID from JWT token
     */
    public UUID getUserIdFromToken(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();

        return UUID.fromString(claims.getSubject());
    }

    /**
     * Validate JWT token
     */
    public boolean validateToken(String token) {
        try {
            Jwts.parser()
                    .verifyWith(secretKey)
                    .build()
                    .parseSignedClaims(token);
            return true;
        } catch (ExpiredJwtException e) {
            log.warn("JWT token is expired: {}", e.getMessage());
        } catch (SignatureException e) {
            log.warn("JWT signature validation failed: {}", e.getMessage());
        } catch (MalformedJwtException | UnsupportedJwtException | IllegalArgumentException e) {
            log.warn("Invalid JWT token: {}", e.getMessage());
        }
        return false;
    }
}
