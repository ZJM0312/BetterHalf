package com.betterhalf.sharing.application;

import com.betterhalf.couple.application.CoupleService;
import com.betterhalf.sharing.domain.ShareToken;
import com.betterhalf.sharing.ports.ShareTokenRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * Service for share token management.
 */
@Service
public class ShareTokenService {
    
    private final ShareTokenRepository shareTokenRepository;
    private final CoupleService coupleService;
    private final SecureRandom secureRandom = new SecureRandom();
    
    public ShareTokenService(
        ShareTokenRepository shareTokenRepository,
        CoupleService coupleService
    ) {
        this.shareTokenRepository = shareTokenRepository;
        this.coupleService = coupleService;
    }
    
    /**
     * Create a share token.
     */
    @Transactional
    public ShareToken createToken(
        UUID coupleId,
        UUID userId,
        String resourceType,
        UUID resourceId,
        Instant expiresAt,
        Integer maxUses
    ) {
        // Verify user is member
        coupleService.getCouple(coupleId, userId);
        
        String token = generateToken();
        
        ShareToken shareToken = new ShareToken();
        shareToken.setCoupleId(coupleId);
        shareToken.setCreatedBy(userId);
        shareToken.setToken(token);
        shareToken.setResourceType(resourceType);
        shareToken.setResourceId(resourceId);
        shareToken.setExpiresAt(expiresAt);
        shareToken.setMaxUses(maxUses);
        shareToken.setUseCount(0);
        shareToken.setRevoked(false);
        
        return shareTokenRepository.save(shareToken);
    }
    
    /**
     * Validate and use a share token.
     */
    @Transactional
    public ShareToken validateAndUse(String token) {
        ShareToken shareToken = shareTokenRepository.findByToken(token)
            .orElseThrow(() -> new IllegalArgumentException("Invalid share token"));
        
        if (!shareToken.isValid()) {
            throw new IllegalArgumentException("Share token expired or revoked");
        }
        
        // Increment use count
        shareToken.setUseCount(shareToken.getUseCount() + 1);
        return shareTokenRepository.save(shareToken);
    }
    
    /**
     * Revoke a share token.
     */
    @Transactional
    public void revokeToken(UUID tokenId, UUID coupleId, UUID userId) {
        ShareToken token = shareTokenRepository.findById(tokenId)
            .orElseThrow(() -> new IllegalArgumentException("Token not found"));
        
        if (!token.getCoupleId().equals(coupleId)) {
            throw new IllegalArgumentException("Token does not belong to this couple");
        }
        
        // Verify user is member
        coupleService.getCouple(coupleId, userId);
        
        token.setRevoked(true);
        shareTokenRepository.save(token);
    }
    
    /**
     * Get token by ID (with authorization).
     */
    public ShareToken getToken(UUID tokenId, UUID coupleId, UUID userId) {
        ShareToken token = shareTokenRepository.findById(tokenId)
            .orElseThrow(() -> new IllegalArgumentException("Token not found"));
        
        if (!token.getCoupleId().equals(coupleId)) {
            throw new IllegalArgumentException("Token does not belong to this couple");
        }
        
        coupleService.getCouple(coupleId, userId);
        
        return token;
    }
    
    private String generateToken() {
        // Generate a secure random token (32 bytes = 64 hex chars)
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        
        StringBuilder token = new StringBuilder();
        for (byte b : bytes) {
            token.append(String.format("%02x", b));
        }
        
        return token.toString();
    }
}
