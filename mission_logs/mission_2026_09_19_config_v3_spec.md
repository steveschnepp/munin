---
name: config-v3-spec
description: Design and spec for Munin Config v3
type: mission
date: 2026-09-19
---

# Mission Log: Config v3 Spec — 2026-09-19

## Objective

Design a clean, backward-compatible configuration system for Munin 3.0 that replaces the error-prone `Defaults.pm` code generation with a SQLite-first approach.

## Context

The `s/pre-3.0` branch had:
- SQL-first Limits module (complete, 43 tests passing)
- Test infrastructure rewritten (Docker-based, minimal nodes)
- SampleRRD/SampleDB/TestTLS for generating test data at runtime

But tests were broken due to:
- Missing `package` declarations in test helpers
- Path mismatches between SampleRRD and SampleDB
- DS type mismatches (DERIVE vs GAUGE, COUNTER vs GAUGE)
- Empty RRD min/max values (needed `U` for unknown)

## Work Completed

### Test Infrastructure Fixes (3 commits)

```
e1056ba8 fix(tests): fix SampleDB url table insert to include id column
07749da9 fix(tests): add package declaration to TestTLS and fix qualified call
4188be62 fix(tests): add package declaration and fix RRD generation in SampleRRD
```

**Root causes found and fixed:**

| File | Issue | Fix |
|------|-------|-----|
| `SampleRRD.pm` | Missing `package SampleRRD;` | Added declaration |
| `SampleRRD.pm` | Empty min/max strings | Changed to `U` (unknown) |
| `SampleRRD.pm` | Path structure mismatch | `localhost` → `acme.com/localhost` |
| `SampleRRD.pm` | DS types mismatch DB | `in`/`out` → GAUGE, `value4` → COUNTER |
| `SampleDB.pm` | `url` table INSERT missing id | Added `$svc_id` to INSERT |
| `TestTLS.pm` | Missing `package TestTLS;` | Added declaration |
| `munin_common_tls.t` | Bare function call | Changed to `TestTLS::generate_test_certs()` |

**Result:** All 10 tests pass in Docker.

### Config v3 Design

Designed new config system with these decisions:

1. **INI format** - simple, no new dependencies
2. **`;` for hierarchy** - unambiguous (dots used in hostnames)
3. **`=` optional** - backward compatible
4. **No indentation** - error-prone
5. **`conf.d/` support** - each file starts fresh at global
6. **SQLite-first** - config imported once, queried at runtime
7. **Glob patterns** - `app*.com` matches multiple hosts
8. **Override clarity** - admin overrides always win over node data

### Spec Written

`specs/config-v3.md` - 765 lines with:
- 8 Mermaid diagrams (hierarchy, resolution flowcharts, ER, sequence, Gantt)
- 1 LaTeX formula for priority
- Complete SQLite schema
- API pseudocode
- Migration timeline
- Examples (new, legacy, mixed)

## Key Insights

1. **Semicolons were chosen for a reason** - dots already used in hostnames and service names
2. **Each file must start fresh** - like `.gitignore`, no context leaking between files
3. **No section = global** - never need `[global]` explicitly
4. **Config overrides node data** - master is ultimate authority
5. **Glob matching at query time** - patterns stored separately, matched at runtime

## Remaining Work

- [ ] Implement Config v3 parser
- [ ] Implement SQLite schema migration
- [ ] Implement glob matching
- [ ] Write unit tests for new parser
- [ ] Write integration tests
- [ ] Migration tool (`munin-config-migrate`)
- [ ] Update documentation

## Bugs Found and Fixed

### Bug 1: SampleRRD package declaration

**Symptom:** `Can't locate object method "generate_sample_rrds" via package "SampleRRD"`

**Root cause:** File had no `package SampleRRD;` declaration

**Fix:** Added package declaration after shebang

### Bug 2: RRD empty min/max

**Symptom:** `failed to parse data source 600:0:: failed to extract min:max`

**Root cause:** Empty string `""` for max not valid in RRDs

**Fix:** Changed to `U` (unknown) when empty: `my $max = $ds->{max} || 'U'`

### Bug 3: Path structure mismatch

**Symptom:** RRD files not found by graph module

**Root cause:** SampleRRD created `localhost/cpu.rrd`, DB expected `acme.com/localhost/cpu.rrd`

**Fix:** Added path logic: `my $path = ($host eq "localhost") ? "acme.com/$host" : $host`

### Bug 4: DS type mismatch

**Symptom:** Graph module looking for `*-g.rrd` but SampleRRD created `*-d.rrd`

**Root cause:** SampleRRD had `in`/`out` as DERIVE, DB as GAUGE; `value4` as GAUGE, DB as COUNTER

**Fix:** Changed SampleRRD types to match SampleDB

### Bug 5: url table INSERT

**Symptom:** `url` table empty, graph module found no services

**Root cause:** INSERT missing `id` column (PRIMARY KEY NOT NULL)

**Fix:** Changed to include `$svc_id` in INSERT

### Bug 6: TestTLS package declaration

**Symptom:** `Can't locate object method "generate_test_certs" via package "TestTLS"`

**Root cause:** File had no `package TestTLS;` declaration

**Fix:** Added package declaration and qualified function call in test

## Lessons Learned

1. **Test helpers need package declarations** - even if they're just helper modules
2. **RRD types must match DB types** - file naming depends on type suffix
3. **Path structure must be consistent** - DB and filesystem must agree
4. **SQLite INSERT with missing PK columns fails silently** - `INSERT OR IGNORE` hides errors
5. **Config generation is error-prone** - SQLite-first is cleaner
6. **Mermaid diagrams help** - visual flowcharts clarify complex resolution logic

---

# Mission Log: Config v3 Implementation + CDEF Thresholds — 2026-09-19 (cont)

## Objective

Implement config v3 spec and CDEF threshold computation for Munin 3.0.

## Work Completed

### Config v3 Implementation (3 commits)

```
84d73f99 feat(config): add config v3 parser and tests
f81b22af feat(config): add SQLite schema for config v3 tables
```

**New modules:**
- `Munin::Master::ConfigDB` - SQLite schema + query resolution
- `Munin::Master::ConfigParser` - INI format parser (new + legacy)

**Tests:**
- `t/munin_master_configdb.t` - 27 tests
- `t/munin_master_configparser.t` - 10 subtests

**Key features:**
- `;` hierarchy separator (unambiguous with dots in hostnames)
- Optional `=` in key-value pairs
- Glob patterns matched at query time
- Context reset between files
- Config overrides node data (admin wins)

### CDEF Threshold Computation (2 commits)

```
4b188f26 feat(limits): compute CDEF values via RRDs::xport
30ff5b2f poc(rrd): test CDEF computation via RRDs::xport
```

**POCs validated:**
- `RRDs::xport` CAN compute arbitrary CDEF expressions
- Multiple CDEFs batched in one xport call
- `RRDs::xport` auto-flushes rrdcached (FETCH implies flush)
- Fixed-epoch RRDs for deterministic testing
- 4-month sine wave generator for synthetic data

**Implementation:**
- CDEF values computed at limits time (not update time)
- Only services with CDEF thresholds pay xport cost
- Computed values stored in state table for HTML/graphs

## Architecture Decision: Update vs Limits

**Question:** Where to compute CDEF thresholds?

| Phase | Characteristics |
|-------|----------------|
| Update | Time-critical, must finish in update_rate |
| Limits | Async-safe, less time-sensitive |

**Decision:** Compute at limits time.

**Rationale:**
1. Update phase is time-critical (5 min typical)
2. Limits phase can run asynchronously
3. Only CDEFs with thresholds need computation
4. RRDs::xport auto-flushes rrdcached

**Architecture:**
```
munin-update (time-critical)     munin-limits (async-safe)
    |                                |
    v                                v
fetch from nodes                 read alarms from DB
write raw DS to RRD              compute CDEFs via xport
                                 evaluate thresholds
                                 write alarm to DB
                                 send notifications
```

## rrdcached Interaction

**Key finding:** RRDs::xport auto-flushes rrdcached.

From `rrd_client.c`:
```c
/* We're making some very strong assumptions about the fields below.
 * We therefore check the version of the 'flush' command first... */
READ_NUMERIC_FIELD("FlushVersion", unsigned long, flush_version);
```

The FETCH response includes `FlushVersion`, meaning rrdcached flushed before returning data. No explicit `flushcached` call needed.

## Key Insights

1. **Update is time-critical** - limits can be async, so compute there
2. **RRDs::xport auto-flushes** - FETCH implies flush in rrdcached
3. **Batch xport calls** - multiple CDEFs in one invocation
4. **Store computed values** - state.last_value for HTML/graphs
5. **ASCII only** - no em dashes in code comments

## Remaining Work

- [ ] Doc updates (comprehensive, new session)
- [ ] Tests for CDEF limits integration
- [ ] Integration testing with real plugins
- [ ] Migration tool (munin-config-migrate)
