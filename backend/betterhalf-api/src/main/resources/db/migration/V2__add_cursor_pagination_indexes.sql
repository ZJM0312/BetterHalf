-- Additional indexes for cursor-based pagination
-- These support efficient cursor pagination queries

-- Events: cursor pagination by created_at
CREATE INDEX idx_events_couple_created_at ON events(couple_id, created_at DESC, id);

-- Events: cursor pagination by event_date
CREATE INDEX idx_events_couple_event_date ON events(couple_id, event_date DESC, id);

-- Media: cursor pagination by created_at
CREATE INDEX idx_media_couple_created_at ON media(couple_id, created_at DESC, id);

-- Memberships: for efficient couple membership lookups
CREATE INDEX idx_memberships_couple_status ON memberships(couple_id, status);
