# BetterHalf API Endpoints

## Base URL
- Development: `http://localhost:8080/api/v1`
- Production: `https://api.betterhalf.com/api/v1`

## Authentication

All endpoints except `/auth/**` require authentication via JWT token in:
- **Header**: `Authorization: Bearer <access_token>`
- **Cookie**: `access_token` (set automatically on login)

## Endpoints

### Authentication (`/auth`)

#### POST `/auth/register`
Register a new user.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securepassword",
  "name": "John Doe"
}
```

**Response:** 201 Created
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "name": "John Doe",
  "accessToken": "jwt_token"
}
```

#### POST `/auth/login`
Login with email and password.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securepassword"
}
```

**Response:** 200 OK
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "name": "John Doe",
  "accessToken": "jwt_token"
}
```

#### POST `/auth/refresh`
Refresh access token using refresh token.

**Headers:**
- `X-Refresh-Token: <refresh_token>` OR
- Cookie: `refresh_token`

**Response:** 200 OK
```json
{
  "accessToken": "new_jwt_token"
}
```

#### POST `/auth/logout`
Logout current session.

**Response:** 204 No Content

#### POST `/auth/logout-all`
Logout from all devices.

**Response:** 204 No Content

#### GET `/auth/me`
Get current user information.

**Response:** 200 OK
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "name": "John Doe",
  "emailVerified": false
}
```

---

### Couples (`/couples`)

#### POST `/couples`
Create a new couple space.

**Request:**
```json
{
  "name": "John & Jane",
  "visibility": "PRIVATE"
}
```

**Response:** 201 Created
```json
{
  "id": "uuid",
  "name": "John & Jane",
  "visibility": "PRIVATE",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

#### GET `/couples/{coupleId}`
Get couple by ID.

**Response:** 200 OK
```json
{
  "id": "uuid",
  "name": "John & Jane",
  "visibility": "PRIVATE",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

#### PUT `/couples/{coupleId}`
Update couple settings.

**Request:**
```json
{
  "name": "Updated Name",
  "visibility": "SHARED"
}
```

**Response:** 200 OK

#### GET `/couples/{coupleId}/members`
Get couple members.

**Response:** 200 OK
```json
[
  {
    "id": "uuid",
    "userId": "uuid",
    "coupleId": "uuid",
    "role": "PARTNER",
    "status": "ACTIVE",
    "joinedAt": "2024-01-01T00:00:00Z"
  }
]
```

#### GET `/couples/me`
Get all couples for current user.

**Response:** 200 OK
```json
[
  {
    "id": "uuid",
    "name": "John & Jane",
    "visibility": "PRIVATE",
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  }
]
```

---

### Events (`/couples/{coupleId}/events`)

#### POST `/couples/{coupleId}/events`
Create a new event.

**Request:**
```json
{
  "title": "First Date",
  "description": "Our first date at the park",
  "eventDate": "2024-01-15",
  "visibility": "INHERIT"
}
```

**Response:** 201 Created
```json
{
  "id": "uuid",
  "coupleId": "uuid",
  "createdBy": "uuid",
  "title": "First Date",
  "description": "Our first date at the park",
  "eventDate": "2024-01-15",
  "visibility": "INHERIT",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

#### GET `/couples/{coupleId}/events`
List events (cursor pagination).

**Query Parameters:**
- `cursor` (optional): UUID cursor for pagination
- `limit` (optional, default: 20): Number of results (max 100)

**Response:** 200 OK
```json
{
  "items": [...],
  "nextCursor": "uuid",
  "hasMore": true
}
```

#### GET `/couples/{coupleId}/events/{eventId}`
Get event by ID.

**Response:** 200 OK

#### PUT `/couples/{coupleId}/events/{eventId}`
Update event.

**Request:**
```json
{
  "title": "Updated Title",
  "description": "Updated description",
  "eventDate": "2024-01-16",
  "visibility": "PRIVATE"
}
```

**Response:** 200 OK

#### DELETE `/couples/{coupleId}/events/{eventId}`
Delete event.

**Response:** 204 No Content

#### GET `/couples/{coupleId}/events/by-date`
Get events by date range.

**Query Parameters:**
- `startDate`: ISO date (required)
- `endDate`: ISO date (required)

**Response:** 200 OK

---

### Media (`/couples/{coupleId}/media`)

#### POST `/couples/{coupleId}/media/upload-init`
Initialize media upload (get presigned URL).

**Request:**
```json
{
  "contentType": "image/jpeg",
  "fileSize": 1048576
}
```

**Response:** 200 OK
```json
{
  "mediaId": "uuid",
  "uploadUrl": "https://s3.amazonaws.com/...",
  "storageKey": "media/uuid"
}
```

#### POST `/couples/{coupleId}/media/{mediaId}/upload-complete`
Complete media upload.

**Request:**
```json
{
  "width": 1920,
  "height": 1080,
  "durationSeconds": null
}
```

**Response:** 200 OK
```json
{
  "id": "uuid",
  "coupleId": "uuid",
  "uploadedBy": "uuid",
  "contentType": "image/jpeg",
  "fileSize": 1048576,
  "width": 1920,
  "height": 1080,
  "visibility": "INHERIT",
  "processingStatus": "PROCESSING",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

#### GET `/couples/{coupleId}/media`
List media (cursor pagination).

**Query Parameters:**
- `cursor` (optional): UUID cursor
- `limit` (optional, default: 20): Number of results

**Response:** 200 OK

#### GET `/couples/{coupleId}/media/{mediaId}`
Get media by ID.

**Response:** 200 OK

#### GET `/couples/{coupleId}/media/{mediaId}/url`
Get signed URL for media access.

**Response:** 200 OK
```json
{
  "url": "https://s3.amazonaws.com/...?signature=..."
}
```

#### DELETE `/couples/{coupleId}/media/{mediaId}`
Delete media.

**Response:** 204 No Content

---

### Share Tokens (`/couples/{coupleId}/share-tokens`)

#### POST `/couples/{coupleId}/share-tokens`
Create a share token.

**Request:**
```json
{
  "resourceType": "EVENT",
  "resourceId": "uuid",
  "expiresAt": "2024-12-31T23:59:59Z",
  "maxUses": 10
}
```

**Response:** 200 OK
```json
{
  "id": "uuid",
  "coupleId": "uuid",
  "token": "hex_token_string",
  "resourceType": "EVENT",
  "resourceId": "uuid",
  "expiresAt": "2024-12-31T23:59:59Z",
  "maxUses": 10,
  "useCount": 0,
  "revoked": false,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

#### GET `/couples/{coupleId}/share-tokens/{tokenId}`
Get share token by ID.

**Response:** 200 OK

#### POST `/couples/{coupleId}/share-tokens/{tokenId}/revoke`
Revoke a share token.

**Response:** 204 No Content

---

## Error Responses

All errors follow this format:

```json
{
  "code": "ERROR_CODE",
  "message": "Human-readable error message",
  "requestId": "uuid",
  "timestamp": "2024-01-01T00:00:00Z",
  "details": {}
}
```

### Common Error Codes

- `VALIDATION_ERROR`: Request validation failed
- `UNAUTHORIZED`: Invalid or missing authentication
- `FORBIDDEN`: Not authorized to perform action
- `BAD_REQUEST`: Invalid request parameters
- `RATE_LIMIT_EXCEEDED`: Too many requests
- `INTERNAL_ERROR`: Server error

## Rate Limiting

Rate limits are returned in response headers:
- `X-RateLimit-Limit`: Maximum requests per window
- `X-RateLimit-Remaining`: Remaining requests
- `Retry-After`: Seconds to wait (if exceeded)

## Pagination

List endpoints use cursor-based pagination:
1. First request: omit `cursor` parameter
2. Subsequent requests: use `nextCursor` from previous response
3. Check `hasMore` to determine if more results exist

## Swagger UI

Interactive API documentation available at:
- `http://localhost:8080/swagger-ui.html`
