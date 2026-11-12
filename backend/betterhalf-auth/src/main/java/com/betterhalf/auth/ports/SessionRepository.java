package com.betterhalf.auth.ports;

import com.betterhalf.auth.domain.Session;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SessionRepository extends JpaRepository<Session, UUID> {
    Optional<Session> findByRefreshTokenHash(String refreshTokenHash);
    List<Session> findByUserIdAndRevokedFalse(UUID userId);
    
    @Modifying
    @Query("UPDATE Session s SET s.revoked = true WHERE s.userId = :userId")
    void revokeAllByUserId(UUID userId);
    
    @Modifying
    @Query("DELETE FROM Session s WHERE s.expiresAt < :now")
    void deleteExpired(Instant now);
}
