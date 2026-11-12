package com.betterhalf.api.web.controller.v1;

import com.betterhalf.api.web.dto.ApiError;
import com.betterhalf.auth.application.AuthService;
import com.betterhalf.auth.domain.User;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/auth")
@Tag(name = "Authentication", description = "User authentication and session management")
public class AuthController {
    
    private final AuthService authService;
    private final boolean cookieSecure;
    private final String cookieSameSite;
    
    public AuthController(
        AuthService authService,
        @Value("${betterhalf.auth.cookie-secure:true}") boolean cookieSecure,
        @Value("${betterhalf.auth.cookie-same-site:Lax}") String cookieSameSite
    ) {
        this.authService = authService;
        this.cookieSecure = cookieSecure;
        this.cookieSameSite = cookieSameSite;
    }
    
    @PostMapping("/register")
    @Operation(summary = "Register a new user")
    public ResponseEntity<AuthResponse> register(
        @Valid @RequestBody RegisterRequest request,
        HttpServletResponse response
    ) {
        User user = authService.register(
            request.email,
            request.password,
            request.name
        );
        
        // Auto-login after registration
        AuthService.LoginResult loginResult = authService.login(
            request.email,
            request.password,
            "Registration",
            null
        );
        
        setAuthCookies(response, loginResult.getAccessToken(), loginResult.getRefreshToken());
        
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(new AuthResponse(user, loginResult.getAccessToken()));
    }
    
    @PostMapping("/login")
    @Operation(summary = "Login with email and password")
    public ResponseEntity<AuthResponse> login(
        @Valid @RequestBody LoginRequest request,
        HttpServletRequest httpRequest,
        HttpServletResponse response
    ) {
        String deviceInfo = httpRequest.getHeader("User-Agent");
        String ipAddress = getClientIp(httpRequest);
        
        AuthService.LoginResult loginResult = authService.login(
            request.email,
            request.password,
            deviceInfo,
            ipAddress
        );
        
        setAuthCookies(response, loginResult.getAccessToken(), loginResult.getRefreshToken());
        
        return ResponseEntity.ok(new AuthResponse(loginResult.getUser(), loginResult.getAccessToken()));
    }
    
    @PostMapping("/refresh")
    @Operation(summary = "Refresh access token")
    public ResponseEntity<RefreshResponse> refresh(
        @CookieValue(value = "refresh_token", required = false) String refreshToken,
        @RequestHeader(value = "X-Refresh-Token", required = false) String headerRefreshToken,
        HttpServletRequest httpRequest,
        HttpServletResponse response
    ) {
        String token = refreshToken != null ? refreshToken : headerRefreshToken;
        if (token == null) {
            throw new IllegalArgumentException("Refresh token required");
        }
        
        String deviceInfo = httpRequest.getHeader("User-Agent");
        String ipAddress = getClientIp(httpRequest);
        
        AuthService.RefreshResult refreshResult = authService.refreshToken(
            token,
            deviceInfo,
            ipAddress
        );
        
        setAuthCookies(response, refreshResult.getAccessToken(), refreshResult.getRefreshToken());
        
        return ResponseEntity.ok(new RefreshResponse(refreshResult.getAccessToken()));
    }
    
    @PostMapping("/logout")
    @Operation(summary = "Logout current session")
    public ResponseEntity<Void> logout(
        @CookieValue(value = "refresh_token", required = false) String refreshToken,
        @RequestHeader(value = "X-Refresh-Token", required = false) String headerRefreshToken,
        HttpServletResponse response
    ) {
        String token = refreshToken != null ? refreshToken : headerRefreshToken;
        if (token != null) {
            authService.logout(token);
        }
        
        clearAuthCookies(response);
        
        return ResponseEntity.noContent().build();
    }
    
    @PostMapping("/logout-all")
    @Operation(summary = "Logout from all devices")
    public ResponseEntity<Void> logoutAll(Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        authService.logoutAll(userId);
        return ResponseEntity.noContent().build();
    }
    
    @GetMapping("/me")
    @Operation(summary = "Get current user")
    public ResponseEntity<UserResponse> getCurrentUser(Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        User user = authService.getCurrentUser(userId)
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        
        return ResponseEntity.ok(new UserResponse(user));
    }
    
    private void setAuthCookies(HttpServletResponse response, String accessToken, String refreshToken) {
        // Access token cookie (short-lived)
        Cookie accessCookie = new Cookie("access_token", accessToken);
        accessCookie.setHttpOnly(true);
        accessCookie.setSecure(cookieSecure);
        accessCookie.setPath("/");
        accessCookie.setMaxAge((int) Duration.ofMinutes(15).getSeconds());
        if ("Strict".equals(cookieSameSite)) {
            accessCookie.setAttribute("SameSite", "Strict");
        } else if ("Lax".equals(cookieSameSite)) {
            accessCookie.setAttribute("SameSite", "Lax");
        }
        response.addCookie(accessCookie);
        
        // Refresh token cookie (long-lived)
        Cookie refreshCookie = new Cookie("refresh_token", refreshToken);
        refreshCookie.setHttpOnly(true);
        refreshCookie.setSecure(cookieSecure);
        refreshCookie.setPath("/");
        refreshCookie.setMaxAge((int) Duration.ofDays(30).getSeconds());
        if ("Strict".equals(cookieSameSite)) {
            refreshCookie.setAttribute("SameSite", "Strict");
        } else if ("Lax".equals(cookieSameSite)) {
            refreshCookie.setAttribute("SameSite", "Lax");
        }
        response.addCookie(refreshCookie);
    }
    
    private void clearAuthCookies(HttpServletResponse response) {
        Cookie accessCookie = new Cookie("access_token", "");
        accessCookie.setHttpOnly(true);
        accessCookie.setPath("/");
        accessCookie.setMaxAge(0);
        response.addCookie(accessCookie);
        
        Cookie refreshCookie = new Cookie("refresh_token", "");
        refreshCookie.setHttpOnly(true);
        refreshCookie.setPath("/");
        refreshCookie.setMaxAge(0);
        response.addCookie(refreshCookie);
    }
    
    private String getClientIp(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
    
    // DTOs
    public static class RegisterRequest {
        @NotBlank
        @Email
        public String email;
        
        @NotBlank
        @Size(min = 8, max = 100)
        public String password;
        
        @NotBlank
        @Size(min = 1, max = 255)
        public String name;
    }
    
    public static class LoginRequest {
        @NotBlank
        @Email
        public String email;
        
        @NotBlank
        public String password;
    }
    
    public static class AuthResponse {
        public UUID id;
        public String email;
        public String name;
        public String accessToken;
        
        public AuthResponse(User user, String accessToken) {
            this.id = user.getId();
            this.email = user.getEmail();
            this.name = user.getName();
            this.accessToken = accessToken;
        }
    }
    
    public static class RefreshResponse {
        public String accessToken;
        
        public RefreshResponse(String accessToken) {
            this.accessToken = accessToken;
        }
    }
    
    public static class UserResponse {
        public UUID id;
        public String email;
        public String name;
        public Boolean emailVerified;
        
        public UserResponse(User user) {
            this.id = user.getId();
            this.email = user.getEmail();
            this.name = user.getName();
            this.emailVerified = user.getEmailVerified();
        }
    }
}
