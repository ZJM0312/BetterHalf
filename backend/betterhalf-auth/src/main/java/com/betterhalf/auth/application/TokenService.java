package com.betterhalf.auth.application;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.UUID;

/**
 * JWT token generation and validation.
 */
@Service
public class TokenService {
    
    private final SecretKey secretKey;
    private final long accessTokenTtlMinutes;
    private final long refreshTokenTtlDays;
    
    public TokenService(
        @Value("${betterhalf.auth.jwt-secret:change-me-in-production-use-256-bit-key}") String jwtSecret,
        @Value("${betterhalf.auth.access-token-ttl:PT15M}") String accessTokenTtl,
        @Value("${betterhalf.auth.refresh-token-ttl:P30D}") String refreshTokenTtl
    ) {
        this.secretKey = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenTtlMinutes = parseDurationToMinutes(accessTokenTtl);
        this.refreshTokenTtlDays = parseDurationToDays(refreshTokenTtl);
    }
    
    /**
     * Generate access token (short-lived).
     */
    public String generateAccessToken(UUID userId, String email) {
        Instant now = Instant.now();
        Instant expiry = now.plus(accessTokenTtlMinutes, ChronoUnit.MINUTES);
        
        return Jwts.builder()
            .subject(userId.toString())
            .claim("email", email)
            .claim("type", "access")
            .issuedAt(Date.from(now))
            .expiration(Date.from(expiry))
            .signWith(secretKey)
            .compact();
    }
    
    /**
     * Generate refresh token (long-lived, stored in DB).
     */
    public String generateRefreshToken(UUID userId) {
        Instant now = Instant.now();
        Instant expiry = now.plus(refreshTokenTtlDays, ChronoUnit.DAYS);
        
        return Jwts.builder()
            .subject(userId.toString())
            .claim("type", "refresh")
            .issuedAt(Date.from(now))
            .expiration(Date.from(expiry))
            .signWith(secretKey)
            .compact();
    }
    
    /**
     * Validate and parse token.
     */
    public Claims validateAndParse(String token) {
        return Jwts.parser()
            .verifyWith(secretKey)
            .build()
            .parseSignedClaims(token)
            .getPayload();
    }
    
    /**
     * Get refresh token expiry.
     */
    public Instant getRefreshTokenExpiry() {
        return Instant.now().plus(refreshTokenTtlDays, ChronoUnit.DAYS);
    }
    
    private long parseDurationToMinutes(String duration) {
        if (duration.startsWith("PT")) {
            String value = duration.substring(2, duration.length() - 1);
            if (duration.endsWith("M")) {
                return Long.parseLong(value);
            } else if (duration.endsWith("H")) {
                return Long.parseLong(value) * 60;
            }
        }
        return 15; // default
    }
    
    private long parseDurationToDays(String duration) {
        if (duration.startsWith("P")) {
            String value = duration.substring(1, duration.length() - 1);
            if (duration.endsWith("D")) {
                return Long.parseLong(value);
            } else if (duration.endsWith("W")) {
                return Long.parseLong(value) * 7;
            } else if (duration.endsWith("M")) {
                return Long.parseLong(value) * 30;
            }
        }
        return 30; // default
    }
}
