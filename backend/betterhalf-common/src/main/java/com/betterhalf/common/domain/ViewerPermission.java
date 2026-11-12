package com.betterhalf.common.domain;

/**
 * Permissions for viewers (read-only members).
 */
public enum ViewerPermission {
    /**
     * Can view all content
     */
    FULL,
    
    /**
     * Can only view content explicitly shared with them
     */
    RESTRICTED
}
