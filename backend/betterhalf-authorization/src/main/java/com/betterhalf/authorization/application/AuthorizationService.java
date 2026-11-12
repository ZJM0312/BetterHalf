package com.betterhalf.authorization.application;

import com.betterhalf.authorization.domain.Actor;
import com.betterhalf.authorization.domain.AuthorizationContext;
import com.betterhalf.authorization.domain.Resource;
import com.betterhalf.common.domain.CoupleInfo;
import com.betterhalf.common.domain.Visibility;
import org.springframework.stereotype.Service;

/**
 * ABAC (Attribute-Based Access Control) authorization service.
 * Central policy engine for all access control decisions.
 */
@Service
public class AuthorizationService {
    
    /**
     * Check if actor can view a couple.
     */
    public boolean canViewCouple(Actor actor, CoupleInfo couple, AuthorizationContext context) {
        // Owner/partner can always view
        if (actor.getCoupleId().equals(couple.getId()) && actor.isPartner()) {
            return true;
        }
        
        // Viewer can view if active member
        if (actor.getCoupleId().equals(couple.getId()) && actor.isViewer() && actor.getViewerPermission() != null) {
            return true;
        }
        
        // Public visibility allows public access
        if (couple.getVisibility() == Visibility.PUBLIC && context.isPublicRequest()) {
            return true;
        }
        
        // Share token access
        if (context.getShareTokenId() != null) {
            // Share token validation happens at repository/service layer
            return true;
        }
        
        return false;
    }
    
    /**
     * Check if actor can write to a couple (create/edit/delete content).
     */
    public boolean canWriteCouple(Actor actor, CoupleInfo couple) {
        // Only partners can write
        if (!actor.getCoupleId().equals(couple.getId())) {
            return false;
        }
        
        return actor.isPartner();
    }
    
    /**
     * Check if actor can view a resource (event, media, etc.).
     */
    public boolean canViewResource(Actor actor, Resource resource, CoupleInfo couple, AuthorizationContext context) {
        // Owner can always view
        if (resource.getOwnerId() != null && resource.getOwnerId().equals(actor.getUserId())) {
            return true;
        }
        
        // Partners can view all content in their couple
        if (actor.getCoupleId().equals(resource.getCoupleId()) && actor.isPartner()) {
            return true;
        }
        
        // Viewers can view based on permission
        if (actor.getCoupleId().equals(resource.getCoupleId()) && actor.isViewer()) {
            if (actor.getViewerPermission() == com.betterhalf.common.domain.ViewerPermission.FULL) {
                return true;
            }
            // RESTRICTED viewers need explicit sharing (handled elsewhere)
        }
        
        // Determine effective visibility
        Visibility effectiveVisibility = resolveVisibility(resource.getVisibility(), couple.getVisibility());
        
        // Public visibility
        if (effectiveVisibility == Visibility.PUBLIC && context.isPublicRequest()) {
            return true;
        }
        
        // Shared visibility with valid share token
        if (effectiveVisibility == Visibility.SHARED && context.getShareTokenId() != null) {
            return true;
        }
        
        return false;
    }
    
    /**
     * Check if actor can write a resource (create/edit/delete).
     */
    public boolean canWriteResource(Actor actor, Resource resource, CoupleInfo couple) {
        // Must be partner in the same couple
        if (!actor.getCoupleId().equals(resource.getCoupleId()) || !actor.isPartner()) {
            return false;
        }
        
        // Owner can always write
        if (resource.getOwnerId() != null && resource.getOwnerId().equals(actor.getUserId())) {
            return true;
        }
        
        // Partners can write to their couple's content
        return true;
    }
    
    /**
     * Check if actor can moderate content.
     */
    public boolean canModerate(Actor actor, CoupleInfo couple) {
        // Only partners can moderate
        if (!actor.getCoupleId().equals(couple.getId())) {
            return false;
        }
        
        return actor.isPartner();
    }
    
    /**
     * Resolve INHERIT visibility to actual visibility.
     * Strong rule: content visibility can only be same or more restrictive than couple default.
     */
    private Visibility resolveVisibility(Visibility resourceVisibility, Visibility coupleVisibility) {
        if (resourceVisibility == Visibility.INHERIT) {
            return coupleVisibility;
        }
        
        // Enforce: content cannot be more permissive than couple
        // PRIVATE < SHARED < PUBLIC
        int resourceLevel = getVisibilityLevel(resourceVisibility);
        int coupleLevel = getVisibilityLevel(coupleVisibility);
        
        // Content must be same or more restrictive (lower or equal level)
        if (resourceLevel > coupleLevel) {
            return coupleVisibility; // Downgrade to couple default
        }
        
        return resourceVisibility;
    }
    
    private int getVisibilityLevel(Visibility visibility) {
        return switch (visibility) {
            case PRIVATE -> 0;
            case SHARED -> 1;
            case PUBLIC -> 2;
            case INHERIT -> -1; // Will be resolved
        };
    }
}
