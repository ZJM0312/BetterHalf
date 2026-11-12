package com.betterhalf.media.application;

import com.betterhalf.authorization.application.AuthorizationService;
import com.betterhalf.authorization.domain.Actor;
import com.betterhalf.authorization.domain.AuthorizationContext;
import com.betterhalf.authorization.domain.Resource;
import com.betterhalf.common.domain.Visibility;
import com.betterhalf.common.util.CursorPagination;
import com.betterhalf.common.util.PageResult;
import com.betterhalf.couple.application.CoupleService;
import com.betterhalf.couple.domain.Couple;
import com.betterhalf.media.domain.Media;
import com.betterhalf.media.ports.MediaRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Service for media management.
 */
@Service
public class MediaService {
    
    private final MediaRepository mediaRepository;
    private final MediaStorageService storageService;
    private final CoupleService coupleService;
    private final AuthorizationService authorizationService;
    
    public MediaService(
        MediaRepository mediaRepository,
        MediaStorageService storageService,
        CoupleService coupleService,
        AuthorizationService authorizationService
    ) {
        this.mediaRepository = mediaRepository;
        this.storageService = storageService;
        this.coupleService = coupleService;
        this.authorizationService = authorizationService;
    }
    
    /**
     * Initialize media upload - returns presigned PUT URL.
     */
    @Transactional
    public UploadInitResult initUpload(UUID coupleId, UUID userId, String contentType, Long fileSize) {
        // Verify user is member
        coupleService.getCouple(coupleId, userId);
        
        // Validate file size and type
        validateUpload(contentType, fileSize);
        
        // Create media record
        Media media = new Media();
        media.setCoupleId(coupleId);
        media.setUploadedBy(userId);
        media.setContentType(contentType);
        media.setFileSize(fileSize);
        media.setStorageKey("media/" + media.getId()); // Will be updated after save
        media.setProcessingStatus("PENDING");
        media.setVisibility(Visibility.INHERIT);
        media = mediaRepository.save(media);
        
        // Update storage key with actual ID
        media.setStorageKey("media/" + media.getId());
        media = mediaRepository.save(media);
        
        // Generate presigned PUT URL
        String uploadUrl = storageService.generatePresignedPutUrl(media.getId(), contentType);
        
        return new UploadInitResult(media.getId(), uploadUrl, media.getStorageKey());
    }
    
    /**
     * Complete media upload - verify and finalize.
     */
    @Transactional
    public Media completeUpload(UUID mediaId, UUID coupleId, UUID userId, Integer width, Integer height, Integer durationSeconds) {
        Media media = mediaRepository.findByIdAndCoupleId(mediaId, coupleId)
            .orElseThrow(() -> new IllegalArgumentException("Media not found"));
        
        if (!media.getUploadedBy().equals(userId)) {
            throw new IllegalArgumentException("Not authorized");
        }
        
        if (!"PENDING".equals(media.getProcessingStatus())) {
            throw new IllegalArgumentException("Upload already completed");
        }
        
        // Update metadata
        if (width != null) {
            media.setWidth(width);
        }
        if (height != null) {
            media.setHeight(height);
        }
        if (durationSeconds != null) {
            media.setDurationSeconds(durationSeconds);
        }
        
        media.setProcessingStatus("PROCESSING");
        // TODO: Enqueue async processing job (thumbnails, video transcode, etc.)
        
        return mediaRepository.save(media);
    }
    
    /**
     * Get media by ID (with authorization).
     */
    public Media getMedia(UUID mediaId, UUID coupleId, UUID userId) {
        Media media = mediaRepository.findByIdAndCoupleId(mediaId, coupleId)
            .orElseThrow(() -> new IllegalArgumentException("Media not found"));
        
        // Authorization check
        Couple couple = coupleService.getCouple(coupleId, userId);
        Actor actor = createActor(userId, coupleId);
        Resource resource = Resource.media(mediaId, coupleId, media.getUploadedBy(), media.getVisibility());
        
        if (!authorizationService.canViewResource(actor, resource, couple, AuthorizationContext.read())) {
            throw new IllegalArgumentException("Not authorized to view this media");
        }
        
        return media;
    }
    
    /**
     * Get signed URL for media access.
     */
    public String getMediaUrl(UUID mediaId, UUID coupleId, UUID userId) {
        Media media = getMedia(mediaId, coupleId, userId);
        return storageService.generatePresignedGetUrl(mediaId);
    }
    
    /**
     * List media for a couple (cursor pagination).
     */
    public PageResult<Media> listMedia(UUID coupleId, UUID userId, CursorPagination pagination) {
        coupleService.getCouple(coupleId, userId);
        
        Pageable pageable = PageRequest.of(0, pagination.getLimit());
        List<Media> mediaList = mediaRepository.findByCoupleIdWithCursor(
            coupleId,
            pagination.getCursor(),
            pageable
        );
        
        UUID nextCursor = null;
        boolean hasMore = false;
        
        if (mediaList.size() > pagination.getLimit()) {
            hasMore = true;
            mediaList = mediaList.subList(0, pagination.getLimit());
            nextCursor = mediaList.get(mediaList.size() - 1).getId();
        } else if (mediaList.size() == pagination.getLimit()) {
            hasMore = mediaRepository.countByCoupleId(coupleId) > pagination.getLimit();
            if (hasMore) {
                nextCursor = mediaList.get(mediaList.size() - 1).getId();
            }
        }
        
        return PageResult.of(mediaList, nextCursor, hasMore);
    }
    
    /**
     * Delete media.
     */
    @Transactional
    public void deleteMedia(UUID mediaId, UUID coupleId, UUID userId) {
        Media media = getMedia(mediaId, coupleId, userId);
        
        // Authorization check
        Couple couple = coupleService.getCouple(coupleId, userId);
        Actor actor = createActor(userId, coupleId);
        Resource resource = Resource.media(mediaId, coupleId, media.getUploadedBy(), media.getVisibility());
        
        if (!authorizationService.canWriteResource(actor, resource, couple)) {
            throw new IllegalArgumentException("Not authorized to delete this media");
        }
        
        // TODO: Delete from storage
        mediaRepository.delete(media);
    }
    
    private void validateUpload(String contentType, Long fileSize) {
        // File size limit (100MB default)
        long maxSize = 100 * 1024 * 1024; // 100MB
        if (fileSize > maxSize) {
            throw new IllegalArgumentException("File size exceeds limit");
        }
        
        // Content type validation
        if (contentType == null || contentType.isEmpty()) {
            throw new IllegalArgumentException("Content type required");
        }
        
        // Basic content type check (can be enhanced)
        if (!contentType.startsWith("image/") && !contentType.startsWith("video/")) {
            throw new IllegalArgumentException("Unsupported content type");
        }
    }
    
    private Actor createActor(UUID userId, UUID coupleId) {
        com.betterhalf.common.domain.MembershipRole role = coupleService.getUserRole(coupleId, userId);
        if (role == com.betterhalf.common.domain.MembershipRole.PARTNER) {
            return Actor.partner(userId, coupleId);
        } else {
            return Actor.viewer(userId, coupleId, null);
        }
    }
    
    public static class UploadInitResult {
        private final UUID mediaId;
        private final String uploadUrl;
        private final String storageKey;
        
        public UploadInitResult(UUID mediaId, String uploadUrl, String storageKey) {
            this.mediaId = mediaId;
            this.uploadUrl = uploadUrl;
            this.storageKey = storageKey;
        }
        
        public UUID getMediaId() {
            return mediaId;
        }
        
        public String getUploadUrl() {
            return uploadUrl;
        }
        
        public String getStorageKey() {
            return storageKey;
        }
    }
}
