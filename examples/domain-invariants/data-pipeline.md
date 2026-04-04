# Domain Invariants: Data Pipeline

Template for projects that process data through transformation pipelines.

## Safety Rules

1. **Idempotent transforms** — running the same input twice produces the same output
2. **Schema validation** — validate input/output schemas at every boundary
3. **No silent data loss** — failed records logged, quarantined, or retried — never dropped
4. **Audit trail** — every mutation tracked with timestamp, source, and actor
5. **Backpressure** — pipelines must handle slow consumers without unbounded memory growth
6. **Checkpoint recovery** — pipelines must be resumable from last successful checkpoint

## Safety-Auditor Scan Patterns

```bash
# Grep for exception swallowing
Grep: except:|catch\s|rescue  across src/**/*
# Each must log/quarantine the error, not silently pass

# Grep for schema validation
# Every ingestion/output point must validate
Grep: validate_schema|Schema\.|@validates  across src/**/*

# No silent drops
Grep: continue|pass|return None  in error handlers
# Must log or quarantine

# Audit trail
Grep: audit_log|create_audit|log_mutation  across src/**/*
# Every write operation must have an audit entry
```

## Hook Configuration

```bash
# safety-gate.sh — file patterns
case "$FILE_PATH" in
  */transforms/*|*/ingestion/*|*/output/*|*/schema/*)
```

## Layer 1 Tests (Safety Invariants)

Must use real data against test pipeline. Never mock I/O boundaries.

- Duplicate input produces identical output (idempotency)
- Malformed input is quarantined with error details, not dropped
- Schema violations are caught before processing
- Every mutation has an audit trail entry
- Pipeline resumes from checkpoint after crash
