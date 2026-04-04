# Domain Invariants: Financial Systems

Template for projects that handle money, transactions, or financial records.

## Safety Rules

1. **No floating-point currency** — all monetary values as integers (cents) or Decimal types
2. **Double-entry bookkeeping** — every debit has a corresponding credit, sum always zero
3. **Audit trail on every mutation** — who, when, what, why — immutable log
4. **No silent failures on transactions** — every transaction succeeds or rolls back completely
5. **Reconciliation checkpoints** — periodic automated checks that books balance
6. **Temporal integrity** — no backdating transactions, all timestamps UTC

## Safety-Auditor Scan Patterns

```bash
# Grep for floating-point currency
Grep: float|double|Float|Double  in monetary calculation modules
# Must use Decimal, BigDecimal, or integer cents

# Grep for transaction boundaries
Grep: transaction|@transactional|BEGIN  across src/**/*
# Every write to financial tables must be in a transaction

# Audit trail
Grep: audit|log_transaction|create_ledger_entry  across src/**/*
# Every mutation must create an audit record

# No silent swallowing
Grep: rescue.*:ok|catch.*return|except.*pass  across src/**/*
# Financial operations must never silently succeed on failure

# Temporal integrity
Grep: created_at.*=|timestamp.*=  in transaction handlers
# Must use server-side NOW(), never client-provided timestamps
```

## Hook Configuration

```bash
# safety-gate.sh — file patterns
case "$FILE_PATH" in
  */ledger/*|*/transactions/*|*/payments/*|*/billing/*)
```

## Layer 1 Tests (Safety Invariants)

Must use real database against test transactions. Never mock financial operations.

- Monetary calculations use Decimal/integer, never float
- Every debit has a matching credit (books balance to zero)
- Failed transactions roll back completely (no partial state)
- Audit log contains entry for every mutation
- Backdated transactions are rejected
- Concurrent transactions on same account serialize correctly
