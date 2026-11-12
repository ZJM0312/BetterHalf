package com.betterhalf.api.web.controller.v1;

import com.betterhalf.common.domain.Visibility;
import com.betterhalf.couple.application.CoupleService;
import com.betterhalf.couple.domain.Couple;
import com.betterhalf.couple.domain.Membership;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/couples")
@Tag(name = "Couples", description = "Couple space management")
@SecurityRequirement(name = "bearerAuth")
public class CoupleController {
    
    private final CoupleService coupleService;
    
    public CoupleController(CoupleService coupleService) {
        this.coupleService = coupleService;
    }
    
    @PostMapping
    @Operation(summary = "Create a new couple space")
    public ResponseEntity<CoupleResponse> createCouple(
        @Valid @RequestBody CreateCoupleRequest request,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        
        Couple couple = coupleService.createCouple(
            userId,
            request.name,
            request.visibility != null ? Visibility.valueOf(request.visibility) : Visibility.PRIVATE
        );
        
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(new CoupleResponse(couple));
    }
    
    @GetMapping("/{coupleId}")
    @Operation(summary = "Get couple by ID")
    public ResponseEntity<CoupleResponse> getCouple(
        @PathVariable UUID coupleId,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        Couple couple = coupleService.getCouple(coupleId, userId);
        return ResponseEntity.ok(new CoupleResponse(couple));
    }
    
    @PutMapping("/{coupleId}")
    @Operation(summary = "Update couple settings")
    public ResponseEntity<CoupleResponse> updateCouple(
        @PathVariable UUID coupleId,
        @Valid @RequestBody UpdateCoupleRequest request,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        
        Couple couple = coupleService.updateCouple(
            coupleId,
            userId,
            request.name,
            request.visibility != null ? Visibility.valueOf(request.visibility) : null
        );
        
        return ResponseEntity.ok(new CoupleResponse(couple));
    }
    
    @GetMapping("/{coupleId}/members")
    @Operation(summary = "Get couple members")
    public ResponseEntity<List<MembershipResponse>> getMembers(
        @PathVariable UUID coupleId,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        List<Membership> memberships = coupleService.getCoupleMembers(coupleId, userId);
        
        List<MembershipResponse> response = memberships.stream()
            .map(MembershipResponse::new)
            .toList();
        
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/me")
    @Operation(summary = "Get my couples")
    public ResponseEntity<List<CoupleResponse>> getMyCouples(Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        List<Membership> memberships = coupleService.getUserMemberships(userId);
        
        // TODO: Batch load couples
        List<CoupleResponse> response = memberships.stream()
            .map(m -> {
                Couple couple = coupleService.getCouple(m.getCoupleId(), userId);
                return new CoupleResponse(couple);
            })
            .toList();
        
        return ResponseEntity.ok(response);
    }
    
    // DTOs
    public static class CreateCoupleRequest {
        @NotBlank
        public String name;
        public String visibility; // PRIVATE, SHARED, PUBLIC
    }
    
    public static class UpdateCoupleRequest {
        public String name;
        public String visibility;
    }
    
    public static class CoupleResponse {
        public UUID id;
        public String name;
        public String visibility;
        public String createdAt;
        public String updatedAt;
        
        public CoupleResponse(Couple couple) {
            this.id = couple.getId();
            this.name = couple.getName();
            this.visibility = couple.getVisibility().name();
            this.createdAt = couple.getCreatedAt().toString();
            this.updatedAt = couple.getUpdatedAt().toString();
        }
    }
    
    public static class MembershipResponse {
        public UUID id;
        public UUID userId;
        public UUID coupleId;
        public String role;
        public String status;
        public String joinedAt;
        
        public MembershipResponse(Membership membership) {
            this.id = membership.getId();
            this.userId = membership.getUserId();
            this.coupleId = membership.getCoupleId();
            this.role = membership.getRole().name();
            this.status = membership.getStatus();
            this.joinedAt = membership.getJoinedAt().toString();
        }
    }
}
