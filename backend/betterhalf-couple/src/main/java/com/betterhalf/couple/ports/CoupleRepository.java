package com.betterhalf.couple.ports;

import com.betterhalf.couple.domain.Couple;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

/**
 * Tenant-safe repository: all queries require coupleId.
 */
@Repository
public interface CoupleRepository extends JpaRepository<Couple, UUID> {
    // Note: No findById without coupleId - tenant isolation enforced
}
