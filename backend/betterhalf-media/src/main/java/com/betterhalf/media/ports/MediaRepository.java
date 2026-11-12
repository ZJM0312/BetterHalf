package com.betterhalf.media.ports;

import com.betterhalf.media.domain.Media;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Tenant-safe repository for media.
 */
@Repository
public interface MediaRepository extends JpaRepository<Media, UUID> {
    
    /**
     * Find by ID and coupleId (tenant isolation).
     */
    Optional<Media> findByIdAndCoupleId(UUID id, UUID coupleId);
    
    /**
     * Find all media for a couple with cursor pagination.
     */
    @Query("SELECT m FROM Media m WHERE m.coupleId = :coupleId " +
           "AND (:cursor IS NULL OR (m.createdAt < (SELECT m2.createdAt FROM Media m2 WHERE m2.id = :cursor) " +
           "OR (m.createdAt = (SELECT m2.createdAt FROM Media m2 WHERE m2.id = :cursor) AND m.id < :cursor))) " +
           "ORDER BY m.createdAt DESC, m.id DESC")
    List<Media> findByCoupleIdWithCursor(
        @Param("coupleId") UUID coupleId,
        @Param("cursor") UUID cursor,
        Pageable pageable
    );
    
    /**
     * Count media for a couple.
     */
    long countByCoupleId(UUID coupleId);
}
