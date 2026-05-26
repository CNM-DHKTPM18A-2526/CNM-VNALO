package iuh.cnm.vnalo.core_service.security;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterTest {

    @Mock
    private JwtTokenProvider jwtTokenProvider;

    @Mock
    private UserDetailsServiceImpl userDetailsService;

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void doFilter_shouldAuthenticateInternalRequestFromRequestUri() throws Exception {
        JwtAuthenticationFilter filter = new JwtAuthenticationFilter(jwtTokenProvider, userDetailsService);
        ReflectionTestUtils.setField(filter, "internalSecret", "VNALO_AI_SECRET_2026");

        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/ai/mascot/internal/settings");
        request.addParameter("userId", "5c3dbff2-48bd-4a36-990a-6d705730bdb8");
        request.addHeader("X-Internal-Secret", "VNALO_AI_SECRET_2026");
        request.setServletPath("");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, new MockFilterChain());

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        assertNotNull(authentication);
        assertEquals("internal-service", authentication.getPrincipal());
        assertTrue(authentication.getAuthorities().stream().anyMatch(a -> "ROLE_INTERNAL".equals(a.getAuthority())));
    }

    @Test
    void doFilter_shouldRejectInternalRequestWithoutMatchingSecret() throws Exception {
        JwtAuthenticationFilter filter = new JwtAuthenticationFilter(jwtTokenProvider, userDetailsService);
        ReflectionTestUtils.setField(filter, "internalSecret", "VNALO_AI_SECRET_2026");

        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/ai/mascot/internal/settings");
        request.addParameter("userId", "5c3dbff2-48bd-4a36-990a-6d705730bdb8");
        request.addHeader("X-Internal-Secret", "wrong-secret");
        request.setServletPath("");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, new MockFilterChain());

        assertEquals(403, response.getStatus());
        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }
}
