---
name: munin-3.0-branch-cleanup
description: Clean up pre-3.0 branch history — remove scratch files, trim bloat
type: mission
date: 2026-09-20
---

# Mission Log: Branch Cleanup — 2026-09-20

## Objective

Clean up the `pre-3.0` branch before merge. The diff against
`origin/master` was 818 files changed, which is way too big for review.

## Diagnosis

The diff was inflated by three categories of junk:

| Category | Files | Size | Issue |
|---|---|---|---|
| `t/sample_data/` | 751 deleted | 69.1 MB | Binary RRD fixtures committed to master, now deleted |
| `t/tls/` | 5 deleted | — | Test certs/keys, now generated at test time |
| `poc/` + `mission_logs/` + `PLAN-3.0.md` | 8 added | ~1.1 KB | Scratch files that shouldn't ship |

After removing these: **54 files changed, +6138/-1251** — the real diff.

## Actions Taken

### 1. Identified the noise

```bash
git diff --stat origin/master..pre-3.0 | tail -3
# 818 files changed, 7264 insertions(+), 1475 deletions(-)

git diff --stat origin/master..pre-3.0 -- . ':!t/sample_data' ':!t/tls' | tail -3
# 62 files changed, 7264 insertions(+), 1251 deletions(-)
```

756 of 818 files were test data deletions. The real work is 62 files.

### 2. Created `3.0-artefacts` branch

Holds the scratch files for reference:

- `poc/rrd_cdef_batch.pl` — CDEF batch computation prototype
- `poc/rrd_cdef_limits.poc` — CDEF limits proof of concept
- `poc/rrd_cdef_test.pl` — CDEF test script
- `poc/rrd_sine.pl` — Sine wave RRD generator
- `poc/rrd_xport_cdef.pl` — xport CDEF prototype
- `mission_logs/mission_2026_09_04_munin_3_0_release_prep.md`
- `mission_logs/mission_2026_09_19_config_v3_spec.md`
- `PLAN-3.0.md`

### 3. Purged scratch files from pre-3.0 history

Used `git filter-branch` to remove `poc/`, `mission_logs/`, and
`PLAN-3.0.md` from all pre-3.0 commits:

```bash
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --index-filter \
  'git rm -rf --cached poc/ mission_logs/ PLAN-3.0.md 2>/dev/null || true' \
  --prune-empty -- origin/master..HEAD
```

Only rewrote 59 commits (the pre-3.0 range), not the full 8500+ history.

### 4. Tagged before destructive ops

`pre-3.0-cleanup` tag marks the state before filter-branch.

## Final State

| Branch | Files vs master | Notes |
|---|---|---|
| `pre-3.0` | 54 files, +6138/-1251 | Clean, ready for review |
| `3.0-artefacts` | Full pre-3.0 + scratch files | Reference only |
| `origin/master` | Unchanged | Upstream untouched |

## Lessons

- **Don't commit scratch files to feature branches.** POC scripts and
  session logs belong in personal notes, not the repo.
- **Binary test fixtures bloat history.** The 751 RRD files were 69 MB
  of binaries in git. Generating them at test time is correct.
- **`git filter-branch -- origin/master..HEAD`** is the safe way to
  rewrite only branch-specific commits without touching shared history.
- **`git filter-repo`** is faster but aggressively removes remotes and
  rewrites refs. Use with caution on shared repos.
