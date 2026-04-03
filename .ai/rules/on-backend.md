# Rules: Backend

Applies when backend/API source files are created or modified.

TODO: Adjust to match your backend framework and conventions.

## API design

- RESTful conventions (or GraphQL — pick one and be consistent)
- Proper HTTP status codes (200, 201, 400, 401, 403, 404, 500)
- Consistent error response format
- Input validation on all endpoints

## Authentication & Authorization

- All endpoints must verify authentication unless explicitly public
- Check authorization (not just authentication) — "is this user allowed to do this?"
- Never trust client-side data for authorization decisions

## Database

- Use parameterized queries — NEVER string concatenation for SQL
- Add indexes for frequently queried columns
- Use transactions for multi-step operations
- Handle concurrent access (optimistic locking, etc.)

## Security

- Never log sensitive data (passwords, tokens, PII)
- Sanitize all user input
- Rate limiting on authentication endpoints
- CORS configuration — be restrictive, not permissive

## Error handling

- Return meaningful error messages to clients
- Log detailed errors server-side (with request context)
- Don't expose internal errors to clients (stack traces, SQL errors)
- Handle all failure modes (network, database, external services)

## Testing

TODO: Define your backend testing strategy:
- Unit tests for business logic
- Integration tests for API endpoints
- Database tests (if applicable)
- Where do test files live?
