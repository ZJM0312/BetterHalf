package com.betterhalf.api.web.controller.v1;

import com.betterhalf.sharing.application.ShareTokenService;
import com.betterhalf.sharing.domain.ShareToken;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/couples/{coupleId}/share-tokens")
@Tag(name = "Share Tokens", description = "Share token management")
@SecurityRequirement(name = "bearerAuth")
public class ShareTokenController {
    
    private final ShareTokenService shareTokenService;
    
    public ShareTokenController(ShareTokenService shareTokenService) {
        this.shareTokenService = shareTokenService;
    }
    
    @PostMapping
    @Operation(summary = "Create a share token")
    public ResponseEntity<ShareTokenResponse> createToken(
        @PathVariable UUID coupleId,
        @Valid @RequestBody CreateShareTokenRequest request,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        
        ShareToken token = shareTokenService.createToken(
            coupleId,
            userId,
            request.resourceType,
            request.resourceId,
            request.expiresAt,
            request.maxUses
        );
        
        return ResponseEntity.ok(new ShareTokenResponse(token));
    }
    
    @GetMapping("/{tokenId}")
    @Operation(summary = "Get share token by ID")
    public ResponseEntity<ShareTokenResponse> getToken(
        @PathVariable UUID coupleId,
        @PathVariable UUID tokenId,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        ShareToken token = shareTokenService.getToken(tokenId, coupleId, userId);
        return ResponseEntity.ok(new ShareTokenResponse(token));
    }
    
    @PostMapping("/{tokenId}/revoke")
    @Operation(summary = "Revoke a share token")
    public ResponseEntity<Void> revokeToken(
        @PathVariable UUID coupleId,
        @PathVariable UUID tokenId,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        shareTokenService.revokeToken(tokenId, coupleId, userId);
        return ResponseEntity.noContent().build();
    }
    
    // DTOs
    public static class CreateShareTokenRequest {
        public String resourceType; // COUPLE, EVENT, MEDIA
        public UUID resourceId;
        
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
        public Instant expiresAt;
        
        public Integer maxUses;
    }
    
    public static class ShareTokenResponse {
        public UUID id;
        public UUID coupleId;
        public String token;
        public String resourceType;
        public UUID resourceId;
        public Instant expiresAt;
        public Integer maxUses;
        public Integer useCount;
        public Boolean revoked;
        public String createdAt;
        
        public ShareTokenResponse(ShareToken token) {
            this.id = token.getId();
            this.coupleId = token.getCoupleId();
            this.token = token.getToken();
            this.resourceType = token.getResourceType();
            this.resourceId = token.getResourceId();
            this.expiresAt = token.getExpiresAt();
            this.maxUses = token.getMaxUses();
            this.useCount = token.getUseCount();
            this.revoked = token.getRevoked();
            this.createdAt = token.getCreatedAt().toString();
        }
    }
}
