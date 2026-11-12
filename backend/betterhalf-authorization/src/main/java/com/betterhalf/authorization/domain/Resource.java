package com.betterhalf.authorization.domain;

import com.betterhalf.common.domain.Visibility;

import java.util.UUID;

/**
 * Represents a resource being accessed.
 * Used in ABAC policy evaluation.
 */
public class Resource {
    private final String type;
    private final UUID id;
    private final UUID coupleId;
    private final UUID ownerId;
    private final Visibility visibility;
    
    public Resource(String type, UUID id, UUID coupleId, UUID ownerId, Visibility visibility) {
        this.type = type;
        this.id = id;
        this.coupleId = coupleId;
        this.ownerId = ownerId;
        this.visibility = visibility;
    }
    
    public static Resource couple(UUID id, Visibility visibility) {
        return new Resource("COUPLE", id, id, null, visibility);
    }
    
    public static Resource event(UUID id, UUID coupleId, UUID ownerId, Visibility visibility) {
        return new Resource("EVENT", id, coupleId, ownerId, visibility);
    }
    
    public static Resource media(UUID id, UUID coupleId, UUID ownerId, Visibility visibility) {
        return new Resource("MEDIA", id, coupleId, ownerId, visibility);
    }
    
    public String getType() {
        return type;
    }
    
    public UUID getId() {
        return id;
    }
    
    public UUID getCoupleId() {
        return coupleId;
    }
    
    public UUID getOwnerId() {
        return ownerId;
    }
    
    public Visibility getVisibility() {
        return visibility;
    }
}
