# Domain Invariants: REST API

Template for projects that expose HTTP APIs.

## Safety Rules

1. **Validate at boundaries** — all external input validated before processing
2. **Auth on every endpoint** — no unauthenticated access to business logic
3. **No raw SQL** — use parameterized queries or ORM exclusively
4. **No secrets in responses** — API keys, passwords, tokens never in response body
5. **No secrets in logs** — sensitive fields redacted before logging
6. **Rate limit all endpoints** — no unlimited access, even internal

## Safety-Auditor Scan Patterns

```bash
# Grep for raw SQL
Grep: query\(|execute\(|raw\(  across src/**/*.{ts,js,py}
# Each must use parameterized queries (?, $1, %s), never string interpolation

# Grep for auth middleware
# Every route file must reference auth middleware
Grep: authenticate|requireAuth|@login_required  across routes/**/*

# No secrets in responses
Grep: password|secret|api_key|token  in response builders
# Must be excluded from serialization

# Rate limiting
Grep: rateLimit|throttle|@rate_limit  across routes/**/*
```

## Hook Configuration

```bash
# safety-gate.sh — file patterns
case "$FILE_PATH" in
  */auth/*|*/middleware/*|*/routes/*|*/queries/*)
```

## Layer 1 Tests (Safety Invariants)

Must use real HTTP calls against test server. Never mock auth.

- Unauthenticated requests return 401
- Invalid input returns 400 with structured error
- SQL injection attempts are rejected
- Response bodies never contain password fields
- Rate limits enforce after threshold
