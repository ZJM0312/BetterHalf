package com.betterhalf.content.application;

import com.betterhalf.authorization.application.AuthorizationService;
import com.betterhalf.authorization.domain.Actor;
import com.betterhalf.authorization.domain.AuthorizationContext;
import com.betterhalf.authorization.domain.Resource;
import com.betterhalf.common.domain.Visibility;
import com.betterhalf.common.util.CursorPagination;
import com.betterhalf.common.util.PageResult;
import com.betterhalf.content.domain.Event;
import com.betterhalf.content.ports.EventRepository;
import com.betterhalf.couple.application.CoupleService;
import com.betterhalf.couple.domain.Couple;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Service for event/timeline management.
 */
@Service
public class EventService {
    
    private final EventRepository eventRepository;
    private final CoupleService coupleService;
    private final AuthorizationService authorizationService;
    
    public EventService(
        EventRepository eventRepository,
        CoupleService coupleService,
        AuthorizationService authorizationService
    ) {
        this.eventRepository = eventRepository;
        this.coupleService = coupleService;
        this.authorizationService = authorizationService;
    }
    
    /**
     * Create a new event.
     */
    @Transactional
    public Event createEvent(UUID coupleId, UUID userId, String title, String description, LocalDate eventDate, Visibility visibility) {
        // Verify user is member
        coupleService.getCouple(coupleId, userId);
        
        Event event = new Event();
        event.setCoupleId(coupleId);
        event.setCreatedBy(userId);
        event.setTitle(title);
        event.setDescription(description);
        event.setEventDate(eventDate);
        event.setVisibility(visibility != null ? visibility : Visibility.INHERIT);
        
        return eventRepository.save(event);
    }
    
    /**
     * Get event by ID (with authorization).
     */
    public Event getEvent(UUID eventId, UUID coupleId, UUID userId) {
        Event event = eventRepository.findByIdAndCoupleId(eventId, coupleId)
            .orElseThrow(() -> new IllegalArgumentException("Event not found"));
        
        // Authorization check
        Couple couple = coupleService.getCouple(coupleId, userId);
        Actor actor = createActor(userId, coupleId);
        Resource resource = Resource.event(eventId, coupleId, event.getCreatedBy(), event.getVisibility());
        
        if (!authorizationService.canViewResource(actor, resource, couple, AuthorizationContext.read())) {
            throw new IllegalArgumentException("Not authorized to view this event");
        }
        
        return event;
    }
    
    /**
     * List events for a couple (cursor pagination).
     */
    public PageResult<Event> listEvents(UUID coupleId, UUID userId, CursorPagination pagination) {
        // Verify user is member
        coupleService.getCouple(coupleId, userId);
        
        Pageable pageable = PageRequest.of(0, pagination.getLimit());
        List<Event> events = eventRepository.findByCoupleIdWithCursor(
            coupleId,
            pagination.getCursor(),
            pageable
        );
        
        UUID nextCursor = null;
        boolean hasMore = false;
        
        if (events.size() > pagination.getLimit()) {
            hasMore = true;
            events = events.subList(0, pagination.getLimit());
            nextCursor = events.get(events.size() - 1).getId();
        } else if (events.size() == pagination.getLimit()) {
            // Check if there are more
            hasMore = eventRepository.countByCoupleId(coupleId) > pagination.getLimit();
            if (hasMore) {
                nextCursor = events.get(events.size() - 1).getId();
            }
        }
        
        return PageResult.of(events, nextCursor, hasMore);
    }
    
    /**
     * Update event.
     */
    @Transactional
    public Event updateEvent(UUID eventId, UUID coupleId, UUID userId, String title, String description, LocalDate eventDate, Visibility visibility) {
        Event event = getEvent(eventId, coupleId, userId);
        
        // Authorization check (only owner or partner can update)
        Couple couple = coupleService.getCouple(coupleId, userId);
        Actor actor = createActor(userId, coupleId);
        Resource resource = Resource.event(eventId, coupleId, event.getCreatedBy(), event.getVisibility());
        
        if (!authorizationService.canWriteResource(actor, resource, couple)) {
            throw new IllegalArgumentException("Not authorized to update this event");
        }
        
        if (title != null) {
            event.setTitle(title);
        }
        if (description != null) {
            event.setDescription(description);
        }
        if (eventDate != null) {
            event.setEventDate(eventDate);
        }
        if (visibility != null) {
            event.setVisibility(visibility);
        }
        
        return eventRepository.save(event);
    }
    
    /**
     * Delete event.
     */
    @Transactional
    public void deleteEvent(UUID eventId, UUID coupleId, UUID userId) {
        Event event = getEvent(eventId, coupleId, userId);
        
        // Authorization check
        Couple couple = coupleService.getCouple(coupleId, userId);
        Actor actor = createActor(userId, coupleId);
        Resource resource = Resource.event(eventId, coupleId, event.getCreatedBy(), event.getVisibility());
        
        if (!authorizationService.canWriteResource(actor, resource, couple)) {
            throw new IllegalArgumentException("Not authorized to delete this event");
        }
        
        eventRepository.delete(event);
    }
    
    /**
     * Get events by date range.
     */
    public List<Event> getEventsByDateRange(UUID coupleId, UUID userId, LocalDate startDate, LocalDate endDate) {
        coupleService.getCouple(coupleId, userId);
        return eventRepository.findByCoupleIdAndDateRange(coupleId, startDate, endDate);
    }
    
    private Actor createActor(UUID userId, UUID coupleId) {
        com.betterhalf.common.domain.MembershipRole role = coupleService.getUserRole(coupleId, userId);
        if (role == com.betterhalf.common.domain.MembershipRole.PARTNER) {
            return Actor.partner(userId, coupleId);
        } else {
            return Actor.viewer(userId, coupleId, null);
        }
    }
}
