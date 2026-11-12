package com.betterhalf.api.web.controller.v1;

import com.betterhalf.common.domain.Visibility;
import com.betterhalf.common.util.CursorPagination;
import com.betterhalf.common.util.PageResult;
import com.betterhalf.content.application.EventService;
import com.betterhalf.content.domain.Event;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/couples/{coupleId}/events")
@Tag(name = "Events", description = "Timeline events management")
@SecurityRequirement(name = "bearerAuth")
public class EventController {
    
    private final EventService eventService;
    
    public EventController(EventService eventService) {
        this.eventService = eventService;
    }
    
    @PostMapping
    @Operation(summary = "Create a new event")
    public ResponseEntity<EventResponse> createEvent(
        @PathVariable UUID coupleId,
        @Valid @RequestBody CreateEventRequest request,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        
        Event event = eventService.createEvent(
            coupleId,
            userId,
            request.title,
            request.description,
            request.eventDate,
            request.visibility != null ? Visibility.valueOf(request.visibility) : null
        );
        
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(new EventResponse(event));
    }
    
    @GetMapping("/{eventId}")
    @Operation(summary = "Get event by ID")
    public ResponseEntity<EventResponse> getEvent(
        @PathVariable UUID coupleId,
        @PathVariable UUID eventId,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        Event event = eventService.getEvent(eventId, coupleId, userId);
        return ResponseEntity.ok(new EventResponse(event));
    }
    
    @GetMapping
    @Operation(summary = "List events (cursor pagination)")
    public ResponseEntity<PageResult<EventResponse>> listEvents(
        @PathVariable UUID coupleId,
        @RequestParam(required = false) UUID cursor,
        @RequestParam(required = false, defaultValue = "20") Integer limit,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        
        CursorPagination pagination = new CursorPagination(cursor, limit);
        PageResult<Event> events = eventService.listEvents(coupleId, userId, pagination);
        
        List<EventResponse> eventResponses = events.getItems().stream()
            .map(EventResponse::new)
            .toList();
        
        PageResult<EventResponse> response = PageResult.of(
            eventResponses,
            events.getNextCursor(),
            events.isHasMore()
        );
        
        return ResponseEntity.ok(response);
    }
    
    @PutMapping("/{eventId}")
    @Operation(summary = "Update event")
    public ResponseEntity<EventResponse> updateEvent(
        @PathVariable UUID coupleId,
        @PathVariable UUID eventId,
        @Valid @RequestBody UpdateEventRequest request,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        
        Event event = eventService.updateEvent(
            eventId,
            coupleId,
            userId,
            request.title,
            request.description,
            request.eventDate,
            request.visibility != null ? Visibility.valueOf(request.visibility) : null
        );
        
        return ResponseEntity.ok(new EventResponse(event));
    }
    
    @DeleteMapping("/{eventId}")
    @Operation(summary = "Delete event")
    public ResponseEntity<Void> deleteEvent(
        @PathVariable UUID coupleId,
        @PathVariable UUID eventId,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        eventService.deleteEvent(eventId, coupleId, userId);
        return ResponseEntity.noContent().build();
    }
    
    @GetMapping("/by-date")
    @Operation(summary = "Get events by date range")
    public ResponseEntity<List<EventResponse>> getEventsByDateRange(
        @PathVariable UUID coupleId,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
        Authentication authentication
    ) {
        UUID userId = UUID.fromString(authentication.getName());
        List<Event> events = eventService.getEventsByDateRange(coupleId, userId, startDate, endDate);
        
        List<EventResponse> response = events.stream()
            .map(EventResponse::new)
            .toList();
        
        return ResponseEntity.ok(response);
    }
    
    // DTOs
    public static class CreateEventRequest {
        @Size(max = 500)
        public String title;
        
        public String description;
        
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
        public LocalDate eventDate;
        
        public String visibility; // PRIVATE, SHARED, PUBLIC, INHERIT
    }
    
    public static class UpdateEventRequest {
        @Size(max = 500)
        public String title;
        
        public String description;
        
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
        public LocalDate eventDate;
        
        public String visibility;
    }
    
    public static class EventResponse {
        public UUID id;
        public UUID coupleId;
        public UUID createdBy;
        public String title;
        public String description;
        public LocalDate eventDate;
        public String visibility;
        public String createdAt;
        public String updatedAt;
        
        public EventResponse(Event event) {
            this.id = event.getId();
            this.coupleId = event.getCoupleId();
            this.createdBy = event.getCreatedBy();
            this.title = event.getTitle();
            this.description = event.getDescription();
            this.eventDate = event.getEventDate();
            this.visibility = event.getVisibility().name();
            this.createdAt = event.getCreatedAt().toString();
            this.updatedAt = event.getUpdatedAt().toString();
        }
    }
}
