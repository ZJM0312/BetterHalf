package com.betterhalf.common.domain;

/**
 * Roles within a couple space.
 */
public enum MembershipRole {
    /**
     * Full partner - can create, edit, delete content
     */
    PARTNER,
    
    /**
     * Viewer - read-only access (may have restricted permissions)
     */
    VIEWER
}
