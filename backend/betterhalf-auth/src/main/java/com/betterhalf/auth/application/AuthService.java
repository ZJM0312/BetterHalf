package com.betterhalf.auth.application;

import com.betterhalf.auth.domain.Session;
import com.betterhalf.auth.domain.User;
import com.betterhalf.auth.ports.SessionRepository;
import com.betterhalf.auth.ports.UserRepository;
import com.betterhalf.common.domain.UserStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.MessageDigest;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * Authentication service handling registration, login, and token management.
 */
@Service
public class AuthService {
    
    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    
    private final UserRepository userRepository;
    private final SessionRepository sessionRepository;
    private final PasswordHasher passwordHasher;
    private final TokenService tokenService;
    
    public AuthService(
        UserRepository userRepository,
        SessionRepository sessionRepository,
        PasswordHasher passwordHasher,
        TokenService tokenService
    ) {
        this.userRepository = userRepository;
        this.sessionRepository = sessionRepository;
        this.passwordHasher = passwordHasher;
        this.tokenService = tokenService;
    }
    
    /**
     * Register a new user.
     */
    @Transactional
    public User register(String email, String password, String name) {
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email already registered");
        }
        
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordHasher.hash(password));
        user.setName(name);
        user.setStatus(UserStatus.ACTIVE);
        user.setEmailVerified(false);
        
        return userRepository.save(user);
    }
    
    /**
     * Authenticate user and create session.
     * Returns access token and refresh token.
     */
    @Transactional
    public LoginResult login(String email, String password, String deviceInfo, String ipAddress) {
        User user = userRepository.findByEmail(email)
            .orElseThrow(() -> new IllegalArgumentException("Invalid credentials"));
        
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new IllegalArgumentException("Account is not active");
        }
        
        if (!passwordHasher.verify(password, user.getPasswordHash())) {
            throw new IllegalArgumentException("Invalid credentials");
        }
        
        // Generate tokens
        String accessToken = tokenService.generateAccessToken(user.getId(), user.getEmail());
        String refreshToken = tokenService.generateRefreshToken(user.getId());
        
        // Create session
        Session session = new Session();
        session.setUserId(user.getId());
        session.setRefreshTokenHash(hashRefreshToken(refreshToken));
        session.setDeviceInfo(deviceInfo);
        session.setIpAddress(ipAddress);
        session.setExpiresAt(tokenService.getRefreshTokenExpiry());
        sessionRepository.save(session);
        
        log.info("User logged in: userId={}, email={}", user.getId(), email);
        
        return new LoginResult(user, accessToken, refreshToken);
    }
    
    /**
     * Refresh access token using refresh token.
     * Implements refresh token rotation for security.
     */
    @Transactional
    public RefreshResult refreshToken(String refreshToken, String deviceInfo, String ipAddress) {
        String tokenHash = hashRefreshToken(refreshToken);
        
        Session session = sessionRepository.findByRefreshTokenHash(tokenHash)
            .orElseThrow(() -> new IllegalArgumentException("Invalid refresh token"));
        
        if (session.getRevoked() || session.isExpired()) {
            throw new IllegalArgumentException("Refresh token expired or revoked");
        }
        
        // Check for token reuse (security: if old token is reused, revoke all sessions)
        if (session.getLastUsedAt().isBefore(Instant.now().minusSeconds(60))) {
            // Token was used more than 60 seconds ago - possible reuse attack
            log.warn("Possible refresh token reuse detected: sessionId={}, userId={}", 
                session.getId(), session.getUserId());
            sessionRepository.revokeAllByUserId(session.getUserId());
            throw new IllegalArgumentException("Refresh token reuse detected");
        }
        
        // Update last used
        session.setLastUsedAt(Instant.now());
        sessionRepository.save(session);
        
        // Get user
        User user = userRepository.findById(session.getUserId())
            .orElseThrow(() -> new IllegalArgumentException("User not found"));
        
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new IllegalArgumentException("Account is not active");
        }
        
        // Generate new tokens (rotation)
        String newAccessToken = tokenService.generateAccessToken(user.getId(), user.getEmail());
        String newRefreshToken = tokenService.generateRefreshToken(user.getId());
        
        // Revoke old session and create new one
        session.setRevoked(true);
        sessionRepository.save(session);
        
        Session newSession = new Session();
        newSession.setUserId(user.getId());
        newSession.setRefreshTokenHash(hashRefreshToken(newRefreshToken));
        newSession.setDeviceInfo(deviceInfo);
        newSession.setIpAddress(ipAddress);
        newSession.setExpiresAt(tokenService.getRefreshTokenExpiry());
        sessionRepository.save(newSession);
        
        return new RefreshResult(newAccessToken, newRefreshToken);
    }
    
    /**
     * Logout - revoke refresh token.
     */
    @Transactional
    public void logout(String refreshToken) {
        String tokenHash = hashRefreshToken(refreshToken);
        sessionRepository.findByRefreshTokenHash(tokenHash)
            .ifPresent(session -> {
                session.setRevoked(true);
                sessionRepository.save(session);
            });
    }
    
    /**
     * Logout from all devices.
     */
    @Transactional
    public void logoutAll(UUID userId) {
        sessionRepository.revokeAllByUserId(userId);
        log.info("All sessions revoked for userId={}", userId);
    }
    
    /**
     * Get current user.
     */
    public Optional<User> getCurrentUser(UUID userId) {
        return userRepository.findById(userId)
            .filter(user -> user.getStatus() == UserStatus.ACTIVE);
    }
    
    private String hashRefreshToken(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(token.getBytes());
            return bytesToHex(hash);
        } catch (Exception e) {
            throw new RuntimeException("Failed to hash refresh token", e);
        }
    }
    
    private String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
    
    public static class LoginResult {
        private final User user;
        private final String accessToken;
        private final String refreshToken;
        
        public LoginResult(User user, String accessToken, String refreshToken) {
            this.user = user;
            this.accessToken = accessToken;
            this.refreshToken = refreshToken;
        }
        
        public User getUser() {
            return user;
        }
        
        public String getAccessToken() {
            return accessToken;
        }
        
        public String getRefreshToken() {
            return refreshToken;
        }
    }
    
    public static class RefreshResult {
        private final String accessToken;
        private final String refreshToken;
        
        public RefreshResult(String accessToken, String refreshToken) {
            this.accessToken = accessToken;
            this.refreshToken = refreshToken;
        }
        
        public String getAccessToken() {
            return accessToken;
        }
        
        public String getRefreshToken() {
            return refreshToken;
        }
    }
}
