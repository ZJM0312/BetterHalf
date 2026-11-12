package com.betterhalf.content.domain;

import com.betterhalf.common.domain.TenantEntity;
import com.betterhalf.common.domain.Visibility;
import jakarta.persistence.*;

import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "events", indexes = {
    @Index(name = "idx_events_couple_id", columnList = "couple_id"),
    @Index(name = "idx_events_created_by", columnList = "created_by"),
    @Index(name = "idx_events_event_date", columnList = "event_date"),
    @Index(name = "idx_events_created_at", columnList = "created_at"),
    @Index(name = "idx_events_couple_created_at", columnList = "couple_id, created_at"),
    @Index(name = "idx_events_couple_event_date", columnList = "couple_id, event_date")
})
public class Event extends TenantEntity {
    
    @Column(name = "created_by")
    private UUID createdBy;
    
    @Column(length = 500)
    private String title;
    
    @Column(columnDefinition = "TEXT")
    private String description;
    
    @Column(name = "event_date")
    private LocalDate eventDate;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Visibility visibility = Visibility.INHERIT;
    
    public UUID getCreatedBy() {
        return createdBy;
    }
    
    public void setCreatedBy(UUID createdBy) {
        this.createdBy = createdBy;
    }
    
    public String getTitle() {
        return title;
    }
    
    public void setTitle(String title) {
        this.title = title;
    }
    
    public String getDescription() {
        return description;
    }
    
    public void setDescription(String description) {
        this.description = description;
    }
    
    public LocalDate getEventDate() {
        return eventDate;
    }
    
    public void setEventDate(LocalDate eventDate) {
        this.eventDate = eventDate;
    }
    
    public Visibility getVisibility() {
        return visibility;
    }
    
    public void setVisibility(Visibility visibility) {
        this.visibility = visibility;
    }
}
