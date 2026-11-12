package com.betterhalf.couple.domain;

import com.betterhalf.common.domain.BaseEntity;
import com.betterhalf.common.domain.MembershipRole;
import com.betterhalf.common.domain.ViewerPermission;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "memberships", 
    uniqueConstraints = @UniqueConstraint(columnNames = {"couple_id", "user_id"}),
    indexes = {
        @Index(name = "idx_memberships_couple_id", columnList = "couple_id"),
        @Index(name = "idx_memberships_user_id", columnList = "user_id"),
        @Index(name = "idx_memberships_status", columnList = "status"),
        @Index(name = "idx_memberships_couple_status", columnList = "couple_id, status")
    })
public class Membership extends BaseEntity {
    
    @Column(nullable = false, name = "couple_id")
    private UUID coupleId;
    
    @Column(nullable = false, name = "user_id")
    private UUID userId;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private MembershipRole role = MembershipRole.PARTNER;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "viewer_permission")
    private ViewerPermission viewerPermission;
    
    @Column(nullable = false)
    private String status = "ACTIVE";
    
    @Column(nullable = false, name = "joined_at", updatable = false)
    private Instant joinedAt;
    
    @PrePersist
    protected void onCreate() {
        if (joinedAt == null) {
            joinedAt = Instant.now();
        }
    }
    
    public UUID getCoupleId() {
        return coupleId;
    }
    
    public void setCoupleId(UUID coupleId) {
        this.coupleId = coupleId;
    }
    
    public UUID getUserId() {
        return userId;
    }
    
    public void setUserId(UUID userId) {
        this.userId = userId;
    }
    
    public MembershipRole getRole() {
        return role;
    }
    
    public void setRole(MembershipRole role) {
        this.role = role;
    }
    
    public ViewerPermission getViewerPermission() {
        return viewerPermission;
    }
    
    public void setViewerPermission(ViewerPermission viewerPermission) {
        this.viewerPermission = viewerPermission;
    }
    
    public String getStatus() {
        return status;
    }
    
    public void setStatus(String status) {
        this.status = status;
    }
    
    public Instant getJoinedAt() {
        return joinedAt;
    }
    
    public void setJoinedAt(Instant joinedAt) {
        this.joinedAt = joinedAt;
    }
    
    public boolean isActive() {
        return "ACTIVE".equals(status);
    }
}
