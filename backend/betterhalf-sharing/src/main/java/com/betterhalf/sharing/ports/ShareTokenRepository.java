package com.betterhalf.sharing.ports;

import com.betterhalf.sharing.domain.ShareToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ShareTokenRepository extends JpaRepository<ShareToken, UUID> {
    Optional<ShareToken> findByToken(String token);
}
