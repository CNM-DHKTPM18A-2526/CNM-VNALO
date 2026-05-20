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
import java.util.Set;

@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final Set<String> INTERNAL_PATH_PREFIXES = Set.of(
            "/api/v1/ai/internal/",
            "/api/v1/ai/mascot/internal/"
    );

    private final JwtTokenProvider jwtTokenProvider;
    private final UserDetailsServiceImpl userDetailsService;

    @org.springframework.beans.factory.annotation.Value("${ai.internal-secret}")
    private String internalSecret;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            String path = resolveRequestPath(request);
            // Handle service-to-service authentication for internal endpoints
            if (isInternalPath(path)) {
                String secret = request.getHeader("X-Internal-Secret");
                if (StringUtils.hasText(internalSecret) && internalSecret.equals(secret)) {
                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken("internal-service", null,
                                    org.springframework.security.core.authority.AuthorityUtils.createAuthorityList("ROLE_INTERNAL"));
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                    log.debug("Internal microservice authenticated for path {}", path);
                    filterChain.doFilter(request, response);
                    return;
                } else {
                    log.warn("Unauthorized internal request for path {}. configuredSecretPresent={}, providedSecretPresent={}",
                            path, StringUtils.hasText(internalSecret), StringUtils.hasText(secret));
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

    private String resolveRequestPath(HttpServletRequest request) {
        String requestUri = request.getRequestURI();
        String contextPath = request.getContextPath();
        if (StringUtils.hasText(contextPath) && StringUtils.hasText(requestUri) && requestUri.startsWith(contextPath)) {
            return requestUri.substring(contextPath.length());
        }
        return StringUtils.hasText(requestUri) ? requestUri : request.getServletPath();
    }

    private boolean isInternalPath(String path) {
        if (!StringUtils.hasText(path)) {
            return false;
        }
        return INTERNAL_PATH_PREFIXES.stream().anyMatch(path::startsWith);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = resolveRequestPath(request);
        if (isInternalPath(path)) {
            return false;
        }
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
