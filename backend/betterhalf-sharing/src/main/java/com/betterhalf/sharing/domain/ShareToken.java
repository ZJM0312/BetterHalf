package com.betterhalf.sharing.domain;

import com.betterhalf.common.domain.BaseEntity;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "share_tokens", indexes = {
    @Index(name = "idx_share_tokens_token", columnList = "token"),
    @Index(name = "idx_share_tokens_couple_id", columnList = "couple_id"),
    @Index(name = "idx_share_tokens_expires_at", columnList = "expires_at")
})
public class ShareToken extends BaseEntity {
    
    @Column(nullable = false, name = "couple_id")
    private UUID coupleId;
    
    @Column(nullable = false, name = "created_by")
    private UUID createdBy;
    
    @Column(nullable = false, unique = true)
    private String token;
    
    @Column(nullable = false, name = "resource_type", length = 50)
    private String resourceType;
    
    @Column(name = "resource_id")
    private UUID resourceId;
    
    @Column(name = "expires_at")
    private Instant expiresAt;
    
    @Column(name = "max_uses")
    private Integer maxUses;
    
    @Column(nullable = false, name = "use_count")
    private Integer useCount = 0;
    
    @Column(nullable = false)
    private Boolean revoked = false;
    
    public UUID getCoupleId() {
        return coupleId;
    }
    
    public void setCoupleId(UUID coupleId) {
        this.coupleId = coupleId;
    }
    
    public UUID getCreatedBy() {
        return createdBy;
    }
    
    public void setCreatedBy(UUID createdBy) {
        this.createdBy = createdBy;
    }
    
    public String getToken() {
        return token;
    }
    
    public void setToken(String token) {
        this.token = token;
    }
    
    public String getResourceType() {
        return resourceType;
    }
    
    public void setResourceType(String resourceType) {
        this.resourceType = resourceType;
    }
    
    public UUID getResourceId() {
        return resourceId;
    }
    
    public void setResourceId(UUID resourceId) {
        this.resourceId = resourceId;
    }
    
    public Instant getExpiresAt() {
        return expiresAt;
    }
    
    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }
    
    public Integer getMaxUses() {
        return maxUses;
    }
    
    public void setMaxUses(Integer maxUses) {
        this.maxUses = maxUses;
    }
    
    public Integer getUseCount() {
        return useCount;
    }
    
    public void setUseCount(Integer useCount) {
        this.useCount = useCount;
    }
    
    public Boolean getRevoked() {
        return revoked;
    }
    
    public void setRevoked(Boolean revoked) {
        this.revoked = revoked;
    }
    
    public boolean isValid() {
        if (revoked) {
            return false;
        }
        if (expiresAt != null && Instant.now().isAfter(expiresAt)) {
            return false;
        }
        if (maxUses != null && useCount >= maxUses) {
            return false;
        }
        return true;
    }
}
