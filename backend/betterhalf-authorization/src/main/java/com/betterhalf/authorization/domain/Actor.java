package com.betterhalf.authorization.domain;

import com.betterhalf.common.domain.MembershipRole;
import com.betterhalf.common.domain.ViewerPermission;

import java.util.UUID;

/**
 * Represents the actor (user) making a request.
 * Used in ABAC policy evaluation.
 */
public class Actor {
    private final UUID userId;
    private final UUID coupleId;
    private final MembershipRole role;
    private final ViewerPermission viewerPermission;
    private final boolean isOwner;
    
    public Actor(UUID userId, UUID coupleId, MembershipRole role, ViewerPermission viewerPermission, boolean isOwner) {
        this.userId = userId;
        this.coupleId = coupleId;
        this.role = role;
        this.viewerPermission = viewerPermission;
        this.isOwner = isOwner;
    }
    
    public static Actor partner(UUID userId, UUID coupleId) {
        return new Actor(userId, coupleId, MembershipRole.PARTNER, null, false);
    }
    
    public static Actor viewer(UUID userId, UUID coupleId, ViewerPermission permission) {
        return new Actor(userId, coupleId, MembershipRole.VIEWER, permission, false);
    }
    
    public static Actor owner(UUID userId, UUID coupleId) {
        return new Actor(userId, coupleId, MembershipRole.PARTNER, null, true);
    }
    
    public UUID getUserId() {
        return userId;
    }
    
    public UUID getCoupleId() {
        return coupleId;
    }
    
    public MembershipRole getRole() {
        return role;
    }
    
    public ViewerPermission getViewerPermission() {
        return viewerPermission;
    }
    
    public boolean isOwner() {
        return isOwner;
    }
    
    public boolean isPartner() {
        return role == MembershipRole.PARTNER;
    }
    
    public boolean isViewer() {
        return role == MembershipRole.VIEWER;
    }
}
