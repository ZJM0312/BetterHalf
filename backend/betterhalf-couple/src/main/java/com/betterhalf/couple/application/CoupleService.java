package com.betterhalf.couple.application;

import com.betterhalf.authorization.application.AuthorizationService;
import com.betterhalf.authorization.domain.Actor;
import com.betterhalf.authorization.domain.AuthorizationContext;
import com.betterhalf.common.domain.MembershipRole;
import com.betterhalf.common.domain.Visibility;
import com.betterhalf.couple.domain.Couple;
import com.betterhalf.couple.domain.Membership;
import com.betterhalf.couple.ports.CoupleRepository;
import com.betterhalf.couple.ports.MembershipRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Service for couple space management.
 */
@Service
public class CoupleService {
    
    private final CoupleRepository coupleRepository;
    private final MembershipRepository membershipRepository;
    private final AuthorizationService authorizationService;
    
    public CoupleService(
        CoupleRepository coupleRepository,
        MembershipRepository membershipRepository,
        AuthorizationService authorizationService
    ) {
        this.coupleRepository = coupleRepository;
        this.membershipRepository = membershipRepository;
        this.authorizationService = authorizationService;
    }
    
    /**
     * Create a new couple space.
     */
    @Transactional
    public Couple createCouple(UUID userId, String name, Visibility visibility) {
        Couple couple = new Couple();
        couple.setName(name);
        couple.setVisibility(visibility);
        couple = coupleRepository.save(couple);
        
        // Create membership for creator as partner
        Membership membership = new Membership();
        membership.setCoupleId(couple.getId());
        membership.setUserId(userId);
        membership.setRole(MembershipRole.PARTNER);
        membership.setStatus("ACTIVE");
        membershipRepository.save(membership);
        
        return couple;
    }
    
    /**
     * Get couple by ID (with authorization check).
     */
    public Couple getCouple(UUID coupleId, UUID userId) {
        Couple couple = coupleRepository.findById(coupleId)
            .orElseThrow(() -> new IllegalArgumentException("Couple not found"));
        
        // Check membership
        Membership membership = membershipRepository.findByCoupleIdAndUserId(coupleId, userId)
            .orElseThrow(() -> new IllegalArgumentException("Not a member of this couple"));
        
        if (!membership.isActive()) {
            throw new IllegalArgumentException("Membership is not active");
        }
        
        return couple;
    }
    
    /**
     * Update couple settings.
     */
    @Transactional
    public Couple updateCouple(UUID coupleId, UUID userId, String name, Visibility visibility) {
        Couple couple = getCouple(coupleId, userId);
        
        // Check authorization (only partners can update)
        Actor actor = createActor(userId, coupleId);
        if (!authorizationService.canWriteCouple(actor, couple)) {
            throw new IllegalArgumentException("Not authorized to update couple");
        }
        
        if (name != null) {
            couple.setName(name);
        }
        if (visibility != null) {
            couple.setVisibility(visibility);
        }
        
        return coupleRepository.save(couple);
    }
    
    /**
     * Get user's memberships.
     */
    public List<Membership> getUserMemberships(UUID userId) {
        return membershipRepository.findActiveByUserId(userId);
    }
    
    /**
     * Get couple members.
     */
    public List<Membership> getCoupleMembers(UUID coupleId, UUID userId) {
        // Verify user is member
        getCouple(coupleId, userId);
        
        return membershipRepository.findActiveByCoupleId(coupleId);
    }
    
    /**
     * Check if user is member of couple.
     */
    public boolean isMember(UUID coupleId, UUID userId) {
        return membershipRepository.isActiveMember(coupleId, userId);
    }
    
    /**
     * Get user's role in couple.
     */
    public MembershipRole getUserRole(UUID coupleId, UUID userId) {
        return membershipRepository.findByCoupleIdAndUserId(coupleId, userId)
            .map(Membership::getRole)
            .orElseThrow(() -> new IllegalArgumentException("Not a member"));
    }
    
    private Actor createActor(UUID userId, UUID coupleId) {
        MembershipRole role = getUserRole(coupleId, userId);
        if (role == MembershipRole.PARTNER) {
            return Actor.partner(userId, coupleId);
        } else {
            // For viewers, we'd need to get permission from membership
            // Simplified for now
            return Actor.viewer(userId, coupleId, null);
        }
    }
}
