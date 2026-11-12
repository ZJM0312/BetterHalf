package com.betterhalf.couple.ports;

import com.betterhalf.couple.domain.Membership;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Tenant-safe repository for memberships.
 */
@Repository
public interface MembershipRepository extends JpaRepository<Membership, UUID> {
    
    /**
     * Find membership by couple and user (tenant-safe).
     */
    Optional<Membership> findByCoupleIdAndUserId(UUID coupleId, UUID userId);
    
    /**
     * Find all active memberships for a couple.
     */
    @Query("SELECT m FROM Membership m WHERE m.coupleId = :coupleId AND m.status = 'ACTIVE'")
    List<Membership> findActiveByCoupleId(@Param("coupleId") UUID coupleId);
    
    /**
     * Find all active memberships for a user.
     */
    @Query("SELECT m FROM Membership m WHERE m.userId = :userId AND m.status = 'ACTIVE'")
    List<Membership> findActiveByUserId(@Param("userId") UUID userId);
    
    /**
     * Check if user is active member of couple.
     */
    @Query("SELECT COUNT(m) > 0 FROM Membership m WHERE m.coupleId = :coupleId AND m.userId = :userId AND m.status = 'ACTIVE'")
    boolean isActiveMember(@Param("coupleId") UUID coupleId, @Param("userId") UUID userId);
}
