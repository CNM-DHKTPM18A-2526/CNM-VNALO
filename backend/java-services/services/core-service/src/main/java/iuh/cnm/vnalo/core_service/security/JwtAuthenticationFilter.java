package iuh.cnm.vnalo.core_service.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenProvider jwtTokenProvider;
    private final UserDetailsServiceImpl userDetailsService;

    @org.springframework.beans.factory.annotation.Value("${ai.internal-secret}")
    private String internalSecret;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            String path = request.getServletPath();
            // Handle service-to-service authentication for internal endpoints
            if (path.startsWith("/api/v1/ai/internal/") || path.startsWith("/api/v1/ai/mascot/internal/")) {
                String secret = request.getHeader("X-Internal-Secret");
                if (internalSecret != null && internalSecret.equals(secret)) {
                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken("internal-service", null,
                                    org.springframework.security.core.authority.AuthorityUtils.createAuthorityList("ROLE_INTERNAL"));
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                    log.debug("Internal microservice authenticated for path {}", path);
                    filterChain.doFilter(request, response);
                    return;
                } else {
                    log.warn("Unauthorized attempt to access internal path {} without valid service secret", path);
                    response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                    response.setContentType("application/json");
                    response.getWriter().write("{\"status\":\"error\",\"message\":\"Access Denied: Invalid Microservice Secret\"}");
                    return;
                }
            }

            String token = extractTokenFromRequest(request);
            if (StringUtils.hasText(token)) {
                if (jwtTokenProvider.validateToken(token)) {
                    String userId = jwtTokenProvider.getUserIdFromToken(token);
                    UserDetails userDetails = userDetailsService.loadUserById(userId);

                    if (userDetails.isEnabled() && userDetails.isAccountNonLocked()) {
                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                        log.debug("User {} authenticated for path {}", userId, request.getServletPath());
                    }
                } else {
                    log.warn("Invalid JWT token provided for path {}", request.getServletPath());
                }
            }
        } catch (Exception ex) {
            log.error("Failed to authenticate user via JWT: {}", ex.getMessage());
        }
        filterChain.doFilter(request, response);
    }

    private String extractTokenFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        // Some /auth endpoints still require authentication, so do NOT skip JWT filter for them.
        // Keep this list in sync with SecurityConfig requestMatchers(...).authenticated().
        if (path.equals("/auth/logout-all")
                || path.equals("/auth/change-password")
                || path.equals("/auth/password/change")
                || path.equals("/auth/login-devices")
                || path.matches("^/auth/qr/sessions/[^/]+/approve$")) {
            return false;
        }
        return path.startsWith("/auth/") || path.startsWith("/swagger-ui")
               || path.startsWith("/v3/api-docs") || path.startsWith("/actuator/health")
               || path.equals("/health") || path.endsWith("/health");
    }
}
