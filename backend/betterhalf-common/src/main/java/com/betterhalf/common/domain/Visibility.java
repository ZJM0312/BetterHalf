package com.betterhalf.common.domain;

/**
 * Content visibility levels.
 * INHERIT means use the couple's default visibility.
 * Visibility can only be same or more restrictive than couple default.
 */
public enum Visibility {
    /**
     * Only members of the couple can see
     */
    PRIVATE,
    
    /**
     * Visible to members and people with share tokens
     */
    SHARED,
    
    /**
     * Publicly visible (for explore/discovery)
     */
    PUBLIC,
    
    /**
     * Inherit visibility from parent (couple default)
     */
    INHERIT
}
