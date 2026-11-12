package com.betterhalf.media.application;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.time.Duration;
import java.util.UUID;

/**
 * Media storage service for direct-to-storage uploads.
 * Uses S3-compatible storage (S3, R2, etc.) with presigned URLs.
 */
@Service
public class MediaStorageService {
    
    private final S3Client s3Client;
    private final S3Presigner presigner;
    private final String bucket;
    private final Duration signedUrlTtl;
    
    public MediaStorageService(
        @Value("${betterhalf.media.storage.bucket}") String bucket,
        @Value("${betterhalf.media.storage.region:us-east-1}") String region,
        @Value("${betterhalf.media.storage.access-key-id:}") String accessKeyId,
        @Value("${betterhalf.media.storage.secret-access-key:}") String secretAccessKey,
        @Value("${betterhalf.media.storage.signed-url-ttl:PT1H}") String signedUrlTtl
    ) {
        this.bucket = bucket;
        this.signedUrlTtl = Duration.parse(signedUrlTtl);
        
        Region awsRegion = Region.of(region);
        
        if (!accessKeyId.isEmpty() && !secretAccessKey.isEmpty()) {
            AwsBasicCredentials credentials = AwsBasicCredentials.create(accessKeyId, secretAccessKey);
            this.s3Client = S3Client.builder()
                .region(awsRegion)
                .credentialsProvider(StaticCredentialsProvider.create(credentials))
                .build();
            this.presigner = S3Presigner.builder()
                .region(awsRegion)
                .credentialsProvider(StaticCredentialsProvider.create(credentials))
                .build();
        } else {
            // Use default credentials (IAM role, env vars, etc.)
            this.s3Client = S3Client.builder()
                .region(awsRegion)
                .build();
            this.presigner = S3Presigner.builder()
                .region(awsRegion)
                .build();
        }
    }
    
    /**
     * Generate presigned PUT URL for direct upload.
     */
    public String generatePresignedPutUrl(UUID mediaId, String contentType) {
        String key = generateStorageKey(mediaId);
        
        PutObjectRequest putObjectRequest = PutObjectRequest.builder()
            .bucket(bucket)
            .key(key)
            .contentType(contentType)
            .build();
        
        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
            .signatureDuration(signedUrlTtl)
            .putObjectRequest(putObjectRequest)
            .build();
        
        PresignedPutObjectRequest presignedRequest = presigner.presignPutObject(presignRequest);
        return presignedRequest.url().toString();
    }
    
    /**
     * Generate presigned GET URL for media access.
     */
    public String generatePresignedGetUrl(UUID mediaId) {
        String key = generateStorageKey(mediaId);
        
        software.amazon.awssdk.services.s3.model.GetObjectRequest getObjectRequest =
            software.amazon.awssdk.services.s3.model.GetObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build();
        
        software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest presignRequest =
            software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest.builder()
                .signatureDuration(signedUrlTtl)
                .getObjectRequest(getObjectRequest)
                .build();
        
        return presigner.presignGetObject(presignRequest).url().toString();
    }
    
    /**
     * Generate storage key for media file.
     */
    private String generateStorageKey(UUID mediaId) {
        // Partition by couple_id prefix for better performance
        // Format: couple/{coupleId}/media/{mediaId}
        // For now, simple: media/{mediaId}
        return "media/" + mediaId.toString();
    }
}
