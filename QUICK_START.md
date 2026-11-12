# BetterHalf Quick Start Guide

## Prerequisites

- Java 21+
- Maven 3.9+
- PostgreSQL 14+
- Redis 6+
- Node.js 18+ and npm
- (Optional) S3-compatible storage (S3, R2, MinIO)

## Setup

### 1. Database Setup

```bash
# Create database
createdb betterhalf

# Or using psql
psql -U postgres
CREATE DATABASE betterhalf;
```

### 2. Redis Setup

```bash
# Start Redis (macOS)
brew services start redis

# Or using Docker
docker run -d -p 6379:6379 redis:7-alpine
```

### 3. Environment Variables

Create `.env` file in `backend/betterhalf-api/`:

```bash
# Database
DATABASE_URL=jdbc:postgresql://localhost:5432/betterhalf
DATABASE_USER=betterhalf
DATABASE_PASSWORD=betterhalf

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# JWT Secret (generate a secure 256-bit key)
JWT_SECRET=your-256-bit-secret-key-here-minimum-32-characters

# Storage (optional for media uploads)
STORAGE_BUCKET=betterhalf-media
STORAGE_REGION=us-east-1
STORAGE_ACCESS_KEY_ID=your-key
STORAGE_SECRET_ACCESS_KEY=your-secret
```

### 4. Build Backend

```bash
cd backend
./mvnw clean install
```

### 5. Run Backend

```bash
cd backend
./mvnw spring-boot:run -pl betterhalf-api
```

The API will start on http://localhost:8080

- API: http://localhost:8080/api/v1
- Swagger UI: http://localhost:8080/swagger-ui.html
- API Docs: http://localhost:8080/api-docs
- Health: http://localhost:8080/actuator/health
- Metrics: http://localhost:8080/actuator/metrics

### 6. Setup Frontend

```bash
cd frontend
npm install
npm run dev
```

Frontend will start on http://localhost:3000

## Architecture Overview

### Backend Modules

- **betterhalf-common**: Shared domain models and utilities
- **betterhalf-authorization**: ABAC policy engine
- **betterhalf-auth**: Authentication and identity
- **betterhalf-couple**: Couple spaces and memberships
- **betterhalf-content**: Timeline, events, notes
- **betterhalf-media**: Media uploads and storage
- **betterhalf-sharing**: Share tokens
- **betterhalf-public**: Public explore/discovery
- **betterhalf-audit**: Audit logging
- **betterhalf-moderation**: Content moderation
- **betterhalf-api**: Main API application

### Key Features Implemented

✅ **Clean Architecture**: Domain, application, ports, adapters separation
✅ **Tenant Isolation**: Strict couple_id enforcement
✅ **ABAC Authorization**: Policy-driven access control
✅ **JWT Authentication**: Cookie-based with refresh token rotation
✅ **Password Security**: Argon2id hashing
✅ **Rate Limiting**: Redis-based per-IP and per-user
✅ **Structured Logging**: MDC with requestId, userId, coupleId
✅ **Metrics & Tracing**: Micrometer + OpenTelemetry ready
✅ **Security Headers**: CSP, X-Frame-Options, etc.
✅ **OpenAPI**: Swagger UI for API documentation
✅ **Cursor Pagination**: Efficient pagination for large datasets
✅ **Optimistic Locking**: Version column for concurrency control

## Next Steps

1. **Implement API Controllers**: Create REST endpoints for auth, couples, events, media
2. **Complete Media Upload**: Finish upload-init and upload-complete flows
3. **Add Application Services**: Business logic layer for use cases
4. **Build Frontend UI**: Authentication, dashboard, media upload
5. **Add Tests**: Unit and integration tests

## Development Tips

### Database Migrations

Migrations are in `backend/betterhalf-api/src/main/resources/db/migration/`

To add a new migration:
1. Create `V{version}__{description}.sql`
2. Follow Flyway naming convention
3. Never modify existing migrations (create new ones for changes)

### Adding a New Module

1. Create module directory: `backend/betterhalf-{name}/`
2. Add `pom.xml` with parent reference
3. Add module to parent `pom.xml`
4. Add dependency to `betterhalf-api/pom.xml`
5. Follow Clean Architecture structure

### Testing Authorization

Use the `AuthorizationService` to check permissions:

```java
@Autowired
private AuthorizationService authorizationService;

Actor actor = Actor.partner(userId, coupleId);
Resource resource = Resource.event(eventId, coupleId, ownerId, visibility);
Couple couple = coupleRepository.findById(coupleId).orElseThrow();

boolean canView = authorizationService.canViewResource(
    actor, resource, couple, AuthorizationContext.read()
);
```

## Troubleshooting

### Database Connection Issues
- Check PostgreSQL is running: `pg_isready`
- Verify credentials in `application.yml`
- Check Flyway migration status in logs

### Redis Connection Issues
- Check Redis is running: `redis-cli ping`
- Verify host/port in `application.yml`

### JWT Errors
- Ensure `JWT_SECRET` is set and at least 32 characters
- Check token expiration times
- Verify token format in requests

### Build Errors
- Ensure Java 21 is installed: `java -version`
- Clean and rebuild: `./mvnw clean install`
- Check module dependencies in `pom.xml` files

## Production Checklist

Before deploying to production:

- [ ] Change `JWT_SECRET` to a secure random value
- [ ] Configure production database (connection pooling, backups)
- [ ] Set up Redis cluster for high availability
- [ ] Configure S3/R2 storage with proper IAM roles
- [ ] Set up CDN for media delivery
- [ ] Configure CORS for production frontend domain
- [ ] Enable HTTPS/TLS everywhere
- [ ] Set up monitoring and alerting
- [ ] Configure log aggregation
- [ ] Set up CI/CD pipeline
- [ ] Review and enable RLS policies if needed
- [ ] Configure rate limits for production traffic
- [ ] Set up backup strategy
- [ ] Review security headers
- [ ] Enable audit logging for sensitive operations
