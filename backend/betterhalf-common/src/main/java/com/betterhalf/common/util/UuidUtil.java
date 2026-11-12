package com.betterhalf.common.util;

import com.github.f4b6a3.uuid.UuidCreator;

import java.util.UUID;

/**
 * UUID utilities for generating time-sortable UUIDs (UUIDv7).
 */
public final class UuidUtil {
    
    private UuidUtil() {
        // Utility class
    }
    
    /**
     * Generate a UUIDv7 (time-sortable).
     * UUIDv7 is time-ordered and suitable for database primary keys.
     */
    public static UUID generate() {
        return UuidCreator.getTimeOrderedEpoch();
    }
}
