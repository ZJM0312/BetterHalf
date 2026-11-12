package com.betterhalf.common.util;

import java.util.List;
import java.util.UUID;

/**
 * Cursor-based pagination result.
 */
public class PageResult<T> {
    private List<T> items;
    private UUID nextCursor;
    private boolean hasMore;
    
    public PageResult(List<T> items, UUID nextCursor, boolean hasMore) {
        this.items = items;
        this.nextCursor = nextCursor;
        this.hasMore = hasMore;
    }
    
    public static <T> PageResult<T> of(List<T> items, UUID nextCursor, boolean hasMore) {
        return new PageResult<>(items, nextCursor, hasMore);
    }
    
    public List<T> getItems() {
        return items;
    }
    
    public UUID getNextCursor() {
        return nextCursor;
    }
    
    public boolean isHasMore() {
        return hasMore;
    }
}
