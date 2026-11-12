package com.betterhalf.content.ports;

import com.betterhalf.content.domain.Event;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Tenant-safe repository: all queries require coupleId.
 */
@Repository
public interface EventRepository extends JpaRepository<Event, UUID> {
    
    /**
     * Find by ID and coupleId (tenant isolation).
     */
    Optional<Event> findByIdAndCoupleId(UUID id, UUID coupleId);
    
    /**
     * Find all events for a couple with cursor pagination.
     */
    @Query("SELECT e FROM Event e WHERE e.coupleId = :coupleId " +
           "AND (:cursor IS NULL OR (e.createdAt < (SELECT e2.createdAt FROM Event e2 WHERE e2.id = :cursor) " +
           "OR (e.createdAt = (SELECT e2.createdAt FROM Event e2 WHERE e2.id = :cursor) AND e.id < :cursor))) " +
           "ORDER BY e.createdAt DESC, e.id DESC")
    List<Event> findByCoupleIdWithCursor(
        @Param("coupleId") UUID coupleId,
        @Param("cursor") UUID cursor,
        Pageable pageable
    );
    
    /**
     * Find events by date range for a couple.
     */
    @Query("SELECT e FROM Event e WHERE e.coupleId = :coupleId " +
           "AND e.eventDate BETWEEN :startDate AND :endDate " +
           "ORDER BY e.eventDate ASC, e.id ASC")
    List<Event> findByCoupleIdAndDateRange(
        @Param("coupleId") UUID coupleId,
        @Param("startDate") LocalDate startDate,
        @Param("endDate") LocalDate endDate
    );
    
    /**
     * Count events for a couple (for pagination).
     */
    long countByCoupleId(UUID coupleId);
}
