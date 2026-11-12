package com.betterhalf.common.domain;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;

import java.util.UUID;

/**
 * Base class for all tenant-scoped entities.
 * Enforces couple_id presence for tenant isolation.
 */
@MappedSuperclass
public abstract class TenantEntity extends BaseEntity {
    
    @Column(nullable = false, name = "couple_id")
    private UUID coupleId;
    
    public UUID getCoupleId() {
        return coupleId;
    }
    
    public void setCoupleId(UUID coupleId) {
        this.coupleId = coupleId;
    }
}
