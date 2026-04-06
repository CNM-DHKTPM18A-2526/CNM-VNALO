package iuh.cnm.vnalo.analytics_service.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class InternalServiceAuthenticationFilter extends OncePerRequestFilter {

    public static final String INTERNAL_SERVICE_AUTHORITY = "INTERNAL_SERVICE";
    private static final String INTERNAL_EVENT_PATH = "/internal/events";
    private static final String INTERNAL_API_KEY_HEADER = "X-Internal-Api-Key";

    @Value("${analytics.internal.api-key}")
    private String internalApiKey;

    @Value("${analytics.internal.client-name:analytics-internal-service}")
    private String internalClientName;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !INTERNAL_EVENT_PATH.equals(request.getRequestURI());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String providedKey = request.getHeader(INTERNAL_API_KEY_HEADER);
        if (StringUtils.hasText(providedKey) && providedKey.equals(internalApiKey)) {
            InternalServicePrincipal principal = InternalServicePrincipal.builder()
                    .clientName(internalClientName)
                    .authorities(List.of(new SimpleGrantedAuthority(INTERNAL_SERVICE_AUTHORITY)))
                    .build();

            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities());
            authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

            SecurityContextHolder.getContext().setAuthentication(authentication);
            filterChain.doFilter(request, response);
            return;
        }

        log.warn("Missing or invalid internal API key for internal analytics request");
        filterChain.doFilter(request, response);
    }
}