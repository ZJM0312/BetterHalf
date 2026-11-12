package com.betterhalf.api.web.controller.v1;

import com.betterhalf.common.util.CursorPagination;
import com.betterhalf.common.util.PageResult;
import com.betterhalf.media.application.MediaService;
import com.betterhalf.media.domain.Media;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/couples/{coupleId}/media")
@Tag(name = "Media", description = "Media upload and management")
@SecurityRequirement(name = "bearerAuth")
public class MediaController {
    
    private final MediaService mediaService;
    
    public MediaController(MediaService mediaService) {
        this.mediaService = mediaService;
    }
    
    @PostMapping("/upload-init")
    @Operation(summary = "Initialize media upload (get presigned URL)")
    public ResponseEntity<UploadInitResponse> initUpload(
        @PathVariable UUID coupleId,
        @Valid @RequestBody UploadInitRequest request,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        
        MediaService.UploadInitResult result = mediaService.initUpload(
            coupleId,
            userId,
            request.contentType,
            request.fileSize
        );
        
        return ResponseEntity.ok(new UploadInitResponse(result));
    }
    
    @PostMapping("/{mediaId}/upload-complete")
    @Operation(summary = "Complete media upload")
    public ResponseEntity<MediaResponse> completeUpload(
        @PathVariable UUID coupleId,
        @PathVariable UUID mediaId,
        @Valid @RequestBody UploadCompleteRequest request,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        
        Media media = mediaService.completeUpload(
            mediaId,
            coupleId,
            userId,
            request.width,
            request.height,
            request.durationSeconds
        );
        
        return ResponseEntity.ok(new MediaResponse(media));
    }
    
    @GetMapping("/{mediaId}")
    @Operation(summary = "Get media by ID")
    public ResponseEntity<MediaResponse> getMedia(
        @PathVariable UUID coupleId,
        @PathVariable UUID mediaId,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        Media media = mediaService.getMedia(mediaId, coupleId, userId);
        return ResponseEntity.ok(new MediaResponse(media));
    }
    
    @GetMapping("/{mediaId}/url")
    @Operation(summary = "Get signed URL for media access")
    public ResponseEntity<MediaUrlResponse> getMediaUrl(
        @PathVariable UUID coupleId,
        @PathVariable UUID mediaId,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        String url = mediaService.getMediaUrl(mediaId, coupleId, userId);
        return ResponseEntity.ok(new MediaUrlResponse(url));
    }
    
    @GetMapping
    @Operation(summary = "List media (cursor pagination)")
    public ResponseEntity<PageResult<MediaResponse>> listMedia(
        @PathVariable UUID coupleId,
        @RequestParam(required = false) UUID cursor,
        @RequestParam(required = false, defaultValue = "20") Integer limit,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        
        CursorPagination pagination = new CursorPagination(cursor, limit);
        PageResult<Media> mediaList = mediaService.listMedia(coupleId, userId, pagination);
        
        List<MediaResponse> responses = mediaList.getItems().stream()
            .map(MediaResponse::new)
            .toList();
        
        PageResult<MediaResponse> response = PageResult.of(
            responses,
            mediaList.getNextCursor(),
            mediaList.isHasMore()
        );
        
        return ResponseEntity.ok(response);
    }
    
    @DeleteMapping("/{mediaId}")
    @Operation(summary = "Delete media")
    public ResponseEntity<Void> deleteMedia(
        @PathVariable UUID coupleId,
        @PathVariable UUID mediaId,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        mediaService.deleteMedia(mediaId, coupleId, userId);
        return ResponseEntity.noContent().build();
    }
    
    // DTOs
    public static class UploadInitRequest {
        @NotNull
        public String contentType;
        
        @NotNull
        @Min(1)
        public Long fileSize;
    }
    
    public static class UploadCompleteRequest {
        public Integer width;
        public Integer height;
        public Integer durationSeconds;
    }
    
    public static class UploadInitResponse {
        public UUID mediaId;
        public String uploadUrl;
        public String storageKey;
        
        public UploadInitResponse(MediaService.UploadInitResult result) {
            this.mediaId = result.getMediaId();
            this.uploadUrl = result.getUploadUrl();
            this.storageKey = result.getStorageKey();
        }
    }
    
    public static class MediaResponse {
        public UUID id;
        public UUID coupleId;
        public UUID uploadedBy;
        public String contentType;
        public Long fileSize;
        public Integer width;
        public Integer height;
        public Integer durationSeconds;
        public String visibility;
        public String processingStatus;
        public String createdAt;
        
        public MediaResponse(Media media) {
            this.id = media.getId();
            this.coupleId = media.getCoupleId();
            this.uploadedBy = media.getUploadedBy();
            this.contentType = media.getContentType();
            this.fileSize = media.getFileSize();
            this.width = media.getWidth();
            this.height = media.getHeight();
            this.durationSeconds = media.getDurationSeconds();
            this.visibility = media.getVisibility().name();
            this.processingStatus = media.getProcessingStatus();
            this.createdAt = media.getCreatedAt().toString();
        }
    }
    
    public static class MediaUrlResponse {
        public String url;
        
        public MediaUrlResponse(String url) {
            this.url = url;
        }
    }
}
