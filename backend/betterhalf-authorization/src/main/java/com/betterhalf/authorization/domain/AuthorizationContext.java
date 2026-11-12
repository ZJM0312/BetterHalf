package com.betterhalf.authorization.domain;

import java.util.UUID;

/**
 * Additional context for authorization decisions.
 */
public class AuthorizationContext {
    private final UUID shareTokenId;
    private final boolean isPublicRequest;
    private final String action; // "read", "write", "delete", "moderate"
    
    public AuthorizationContext(UUID shareTokenId, boolean isPublicRequest, String action) {
        this.shareTokenId = shareTokenId;
        this.isPublicRequest = isPublicRequest;
        this.action = action;
    }
    
    public static AuthorizationContext read() {
        return new AuthorizationContext(null, false, "read");
    }
    
    public static AuthorizationContext write() {
        return new AuthorizationContext(null, false, "write");
    }
    
    public static AuthorizationContext withShareToken(UUID shareTokenId) {
        return new AuthorizationContext(shareTokenId, false, "read");
    }
    
    public static AuthorizationContext publicRead() {
        return new AuthorizationContext(null, true, "read");
    }
    
    public UUID getShareTokenId() {
        return shareTokenId;
    }
    
    public boolean isPublicRequest() {
        return isPublicRequest;
    }
    
    public String getAction() {
        return action;
    }
    
    public boolean isRead() {
        return "read".equals(action);
    }
    
    public boolean isWrite() {
        return "write".equals(action);
    }
}
