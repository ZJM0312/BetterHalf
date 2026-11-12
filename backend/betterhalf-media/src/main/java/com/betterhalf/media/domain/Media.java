package com.betterhalf.media.domain;

import com.betterhalf.common.domain.TenantEntity;
import com.betterhalf.common.domain.Visibility;
import jakarta.persistence.*;

import java.util.UUID;

@Entity
@Table(name = "media", indexes = {
    @Index(name = "idx_media_couple_id", columnList = "couple_id"),
    @Index(name = "idx_media_uploaded_by", columnList = "uploaded_by"),
    @Index(name = "idx_media_processing_status", columnList = "processing_status"),
    @Index(name = "idx_media_created_at", columnList = "created_at"),
    @Index(name = "idx_media_couple_created_at", columnList = "couple_id, created_at")
})
public class Media extends TenantEntity {
    
    @Column(nullable = false, name = "uploaded_by")
    private UUID uploadedBy;
    
    @Column(nullable = false, name = "storage_key", length = 500)
    private String storageKey;
    
    @Column(nullable = false, name = "content_type", length = 100)
    private String contentType;
    
    @Column(nullable = false, name = "file_size")
    private Long fileSize;
    
    private Integer width;
    private Integer height;
    
    @Column(name = "duration_seconds")
    private Integer durationSeconds;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Visibility visibility = Visibility.INHERIT;
    
    @Column(nullable = false, name = "processing_status")
    private String processingStatus = "PENDING";
    
    @Column(columnDefinition = "JSONB")
    private String metadata;
    
    public UUID getUploadedBy() {
        return uploadedBy;
    }
    
    public void setUploadedBy(UUID uploadedBy) {
        this.uploadedBy = uploadedBy;
    }
    
    public String getStorageKey() {
        return storageKey;
    }
    
    public void setStorageKey(String storageKey) {
        this.storageKey = storageKey;
    }
    
    public String getContentType() {
        return contentType;
    }
    
    public void setContentType(String contentType) {
        this.contentType = contentType;
    }
    
    public Long getFileSize() {
        return fileSize;
    }
    
    public void setFileSize(Long fileSize) {
        this.fileSize = fileSize;
    }
    
    public Integer getWidth() {
        return width;
    }
    
    public void setWidth(Integer width) {
        this.width = width;
    }
    
    public Integer getHeight() {
        return height;
    }
    
    public void setHeight(Integer height) {
        this.height = height;
    }
    
    public Integer getDurationSeconds() {
        return durationSeconds;
    }
    
    public void setDurationSeconds(Integer durationSeconds) {
        this.durationSeconds = durationSeconds;
    }
    
    public Visibility getVisibility() {
        return visibility;
    }
    
    public void setVisibility(Visibility visibility) {
        this.visibility = visibility;
    }
    
    public String getProcessingStatus() {
        return processingStatus;
    }
    
    public void setProcessingStatus(String processingStatus) {
        this.processingStatus = processingStatus;
    }
    
    public String getMetadata() {
        return metadata;
    }
    
    public void setMetadata(String metadata) {
        this.metadata = metadata;
    }
}
