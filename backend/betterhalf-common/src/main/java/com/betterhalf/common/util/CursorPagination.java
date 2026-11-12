package com.betterhalf.common.util;

import java.util.UUID;

/**
 * Cursor-based pagination parameters.
 */
public class CursorPagination {
    private UUID cursor;
    private Integer limit;
    
    public CursorPagination() {
        this.limit = 20; // default
    }
    
    public CursorPagination(UUID cursor, Integer limit) {
        this.cursor = cursor;
        this.limit = limit != null ? Math.min(limit, 100) : 20; // max 100
    }
    
    public UUID getCursor() {
        return cursor;
    }
    
    public void setCursor(UUID cursor) {
        this.cursor = cursor;
    }
    
    public Integer getLimit() {
        return limit;
    }
    
    public void setLimit(Integer limit) {
        this.limit = limit != null ? Math.min(limit, 100) : 20;
    }
    
    public boolean hasCursor() {
        return cursor != null;
    }
}
