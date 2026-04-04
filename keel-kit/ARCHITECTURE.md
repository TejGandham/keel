# Architecture

<!-- DELETE AFTER FILLING: Replace all sections with your project's architecture.
     Keep the section structure — it's what agents expect. Remove instruction comments. -->

## Overview

<!-- 1-3 sentences: what kind of app, key architectural pattern, data strategy -->
[YOUR APP TYPE]. [KEY PATTERN]. [DATA STRATEGY].

## Process / Component Model

<!-- Show your supervision tree, service topology, or component hierarchy.
     Use ASCII diagrams — agents parse these well. -->
```
[YOUR PROCESS MODEL]
```

## Data Flow

<!-- Trace a typical user action through the system, showing which
     modules/services handle each step. -->
```
User does [ACTION]
  → [MODULE A] handles request
  → [MODULE B] processes
  → [MODULE C] persists/responds
  → Result returned to user
```

## Module Map

<!-- List every module with its file, responsibility, and dependencies.
     This is what agents read to understand what calls what. -->

| Module | File | Responsibility | Depends On |
|--------|------|---------------|------------|
| <!-- CUSTOMIZE --> | | | |

## Layer Dependencies

<!-- Show your architectural layers and dependency direction.
     Dependencies must flow strictly in one direction. -->

```
[UI Layer]              ← Features F??-F??
      ↓
[Service Layer]         ← Features F??-F??
      ↓
[Foundation Layer]      ← Features F??-F??
```

Cross-cutting: [LIST CROSS-CUTTING CONCERNS]

## Key Design Decisions

<!-- Document decisions that agents need to understand.
     Each decision: what was chosen and WHY. -->

- **[DECISION]:** [rationale]

## Container Architecture

<!-- If using Docker, show the container topology. -->
```
[YOUR CONTAINER DIAGRAM]
```
