# Lane187 — Production SPURS compact-context runtime canary instrumentation

Date: 2026-09-12
Branch: `team/prod-spurs-canary-instrumentation`
Base: `5e4df70917bc917bf313b06774fb9ad798f93df7` (Lane178)
Scope: temporary validation-only source instrumentation + this report. **No build, compile, test, GTA run/probe, APK/NDK action, install, push, merge, workflow dispatch, or heavyweight job was performed.**

## Result

Implemented the Lane183 Strategy-B canary directly around Lane178's real compact SPURS context save/restore operations. Lane178's compact algorithm itself is not refactored or replaced: sizing remains `0x400 + popcount(pattern) * 0x800`; selected LS blocks still map in ascending real-block order to `context + 0x400 + (slot << 11)`; and `slot` still advances only for selected blocks. The original processor and selected-block `memcpy` operations remain the actual copy operations.

The instrumentation is deliberately temporary and is **not** production merge code. The eventual production candidate must return byte-for-byte to Lane178 after the canary evidence is collected.

## Required inputs read first

1. `/data/data/com.termux/files/home/.cache/gd-team-tasks/lane187.md`
2. `/data/data/com.termux/files/home/projects/android/gamedeck-ps3-live-lanes-20260908/TEAM_RESOURCE_POLICY.md`
3. `../lane183-prod-spurs-functional-test-review/AGENT_RESULT.md`

The resource policy permits source inspection/editing but prohibits unguarded heavyweight work. This lane did no heavyweight work at all.

## Exact files and symbols changed

### `app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpurs.cpp`

Changed only validation/provenance logging around existing candidate logic:

- `spurs_task_context_save_area_size()` — **not semantically changed**. It still rejects SPURS management-area bits, popcounts the four pattern words, and computes `CELL_SPURS_TASK_EXECUTION_CONTEXT_SIZE + saved_blocks * 0x800` (current lines 4116-4133).
- Added `spurs_task_pattern_is_bink_canary()` (current lines 4140-4146) for the exact authentic pattern `00000000:00000040:00000000:00000001`.
- `spurs_decode_task_attribute_v1()` — after the existing required-size check succeeds, emits `SPURS_CANARY phase=DECODE` only for the exact Bink descriptor with `context_size == required_size == 0x1400` (current lines 4193-4209).
- `_spurs::create_task()` — existing allocation computation/validation remains at current lines 4256-4274 and the existing packed TaskInfo publication remains at line 4320. After publication, emits `SPURS_CANARY phase=CREATE` only for exact Bink `size=0x1400`, `alloc=2` (current lines 4327-4332).

### `app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpursSpu.cpp`

Added temporary canary helpers and instrumentation in the **actual** production save/restore paths:

- `spursCanaryIsBinkPattern()` — exact pattern recognition.
- `spursCanaryHash()` — wraps the existing in-tree `sha256_get_hash()` from `Crypto/utils.h`.
- `spursCanaryCheckContextRange()` — checked host arithmetic + TaskInfo-capacity/LS-range validation; emits `SPURS_CANARY_FAIL ... reason=range` and calls repository-native `spursHalt(spu)` before an invalid real copy can execute.
- `spursCanaryCheckBinkMapping()` — fail-stop assertion for the exact two legal Bink mappings and explicit rejection of historical sparse offsets.
- `spursCanaryClaimBinkSave()` / `spursCanaryMatchesSavedBink()` — process-local atomic diagnostic state limiting expensive hashing to the first exact Bink save and its later same-identity restore.
- `spursTasketSaveTaskContext(spu_thread&)` — actual save path instrumented in place.
- `spursTasksetDispatch(spu_thread&)` — actual `isWaiting != 0` resume branch instrumented in place after the pre-existing clear/ELF-reload logic.

No alternate save/restore copy helper was introduced. No scheduler, EventFlag, DMA, task-state, ELF-load, resume, or guest-visible bypass semantics were changed.

## Source hashes

Lane178/base hashes before instrumentation, independently matched before editing:

- `cellSpurs.cpp`: `318d9d982714fcb2090dd62a0336fb4c134ae64fff32a0de4d2c8bd3b04cb9c2`
- `cellSpursSpu.cpp`: `5a83d06e6f1e82c94b36459bd69a3141b311a52383d294e271fb109f39b1f1c6`

Lane187 instrumented hashes after the final source edit:

- `cellSpurs.cpp`: `c1c3731fd34823eebd88d87ab5bde00f38147e7e78d68bd93d898440161dd6f4`
- `cellSpursSpu.cpp`: `f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570`

After the future canary run, removal of all Lane187 instrumentation must restore the two Lane178 hashes above exactly before production review/merge.

## Diagnostic gating choice

No safe existing runtime diagnostic gate was found in these two SPURS paths during source inspection. Therefore:

- lightweight pre-copy bounds/fail-stop checks apply to every real context copy;
- expensive SHA-256 payload/gap/neighbor hashing and detailed `SAVE_*`/`RESTORE_*` provenance are limited to the **first** exact authentic Bink save descriptor and the later restore with the same `{taskset, task, contextBase}` identity;
- exact Bink `DECODE`/`CREATE` provenance is cheap and may be emitted when that descriptor is decoded/created;
- no guest-visible switch, fabricated task, readiness bypass, or alternate copy path exists.

The first-Bink state is host-only diagnostic state. The claim occurs only after the fixed context range has passed the TaskInfo-derived bounds check.

## Marker schema

### Creation/sizing provenance

`SPURS_CANARY phase=DECODE`

Fields: `revision sdk elf context size required pattern`.

`SPURS_CANARY phase=CREATE`

Fields: `taskset task context size required alloc packed pattern`.

### Save

`SPURS_CANARY phase=SAVE_BEGIN`

Fields include: `taskset task context capacity alloc pattern popcount fixed_off fixed_len fixed_end gap`.

`SPURS_CANARY phase=SAVE_COPY`

Fields include: `taskset task context capacity alloc pattern block slot ctx_off ctx_end ls_start ls_end src_sha256 dst_sha256 equal`.

`SPURS_CANARY phase=SAVE_END`

Fields include: `taskset task context capacity alloc popcount slot slot_ok spare_start spare_end gap_before_sha256 gap_after_sha256 gap_equal`.

### Restore

`SPURS_CANARY phase=RESTORE_BEGIN`

Fields include the same identity/geometry plus `isWaiting` to prove this came from the actual resume branch.

`SPURS_CANARY phase=RESTORE_COPY`

Fields include the same copy provenance and payload SHA equality plus local unsaved-neighbor fields: `neighbor_a_block`, before/after SHA and equality; optional `neighbor_b_*` for block57.

`SPURS_CANARY phase=RESTORE_END`

Fields include slot/popcount/allocation arithmetic and reserved-gap before/after SHA equality.

### Fail-stop

`SPURS_CANARY_FAIL phase=<...> reason=<range|bink_mapping|hash_mismatch|slot_count|gap_modified> ...`

A fail marker is followed by repository-native `spursHalt(spu)` and an immediate return from the instrumented path, so the invalid real `memcpy` does not execute. No clamping, skipping-as-success, fabricated data, or continuation occurs.

## Acceptance-condition audit

### 1. Preserve Lane178 compact algorithm

PASS by source review. `spurs_task_context_save_area_size()` remains `0x400 + popcount(pattern)*0x800`. Both real selected-block copies still use the pre-existing compact expression `contextSaveStorage + 0x400 + (slot << 11)`, and `slot++` remains inside the selected-block conditional only. Instrumentation computes parallel host-side geometry but does not replace the real copy expression.

### 2. Instrument actual save and restore paths

PASS by source review. Save instrumentation is in `spursTasketSaveTaskContext(spu_thread&)`. Restore instrumentation is in the existing `else` branch of `spursTasksetDispatch(spu_thread&)`, i.e. the `isWaiting != 0` resume path, after the existing optional clear-LS and ELF reload.

### 3. Capacity only from TaskInfo; checked arithmetic before every observed real context copy

PASS by source review.

For save and restore:

- `allocLsBlocks = packed & 0x7f` (save reuses its already-existing low-seven-bit extraction; restore derives it explicitly);
- `contextBase = packed & -0x80ull`;
- `capacity = 0x400 + allocLsBlocks * 0x800`.

`spursCanaryCheckContextRange()` computes `end = offset + length` in host `u64`, requires `end >= offset`, `end <= capacity`, and separately protects `contextBase + end` from wrap/out-of-32-bit guest range. LS payload copies additionally require `slot < allocLsBlocks`, `offset >= 0x400`, and `CELL_SPURS_TASK_TOP <= ls_start <= ls_end <= CELL_SPURS_TASK_BOTTOM`. Any violation fail-stops before the real copy.

No adjacent allocation or external canary is used as bounds authority.

### 4. Processor context and reserved gap

PASS by source review / ready for runtime evidence.

The real fixed copy remains exactly offset `+0x000`, length `0x380`, exclusive end `+0x380`. Payload checks require context offset `>= +0x400`, so selected LS copies cannot target `+0x380..+0x3ff`.

For the first exact Bink cycle, the legal `+0x380..+0x3ff` region is range-checked and SHA-256 hashed before/after save and before/after restore. No gap read is performed before the range check, and no diagnostic reads at or beyond `contextBase + capacity`.

### 5. Authentic Bink identity and structured markers

PASS by source review / ready for runtime evidence.

Exact pattern match is `00000000:00000040:00000000:00000001`; detailed save/restore requires `alloc=2`, hence TaskInfo capacity `0x1400`. DECODE requires `size==required==0x1400`; CREATE requires `size=0x1400`, `alloc=2`. Structured phases implemented: `DECODE`, `CREATE`, `SAVE_BEGIN`, `SAVE_COPY`, `SAVE_END`, `RESTORE_BEGIN`, `RESTORE_COPY`, `RESTORE_END`.

### 6. Exact Bink mappings and historical sparse-offset rejection

PASS by source assertion / ready for runtime evidence.

The first exact Bink cycle must satisfy:

- block57 / slot0: context `[+0x400,+0xc00)` ↔ LS `[0x1c800,0x1d000)`;
- block127 / slot1: context `[+0xc00,+0x1400)` ↔ LS `[0x3f800,0x40000)`.

The Bink mapping checker rejects any other selected block/slot geometry, rejects `ctx_off == 0x19c00` or `0x3cc00`, requires `ctx_off < 0x1400`, and requires `ctx_end <= 0x1400`. General capacity checking also precedes every real payload copy.

### 7. Byte consistency and local unsaved-neighbor proof

PASS by source review / ready for runtime evidence.

Save, first exact Bink cycle only:

1. SHA-256 selected 0x800-byte LS source immediately before real memcpy.
2. Execute the unchanged real memcpy.
3. SHA-256 legal context destination immediately after.
4. Log and require equality; mismatch fail-stops.

Restore, same saved Bink identity only:

1. SHA-256 legal context source immediately before real memcpy.
2. Hash local unsaved LS neighbors immediately before that selected-block memcpy.
3. Execute the unchanged real memcpy.
4. SHA-256 LS destination and the same local neighbors immediately after.
5. Log/require selected payload equality and neighbor equality; mismatch fail-stops.

Neighbors are exactly:

- restoring block57: block56 `[0x1c000,0x1c800)` and block58 `[0x1d000,0x1d800)`;
- restoring block127: block126 `[0x3f000,0x3f800)`; there is no block128 task destination.

No neighbor comparison spans the suspend interval, so legitimate ELF reload behavior is not mistaken for compact-restore spill.

Offline same-task roundtrip correlation must require each `SAVE_COPY dst_sha256` to equal the matching later `RESTORE_COPY src_sha256` for the same `{taskset,task,context,pattern,block,slot}`.

### 8. Loop-end slot invariant and spare capacity

PASS by source enforcement.

At the end of both real loops, any `slot != popcount(pattern)` or `slot > allocLsBlocks` emits a fail marker and halts. Successful detailed Bink end markers log `slot`, `popcount`, `alloc`, `slot_ok`, `spare_start = 0x400 + slot*0x800`, and `spare_end = capacity`.

For any source case `alloc > popcount`, the loop can generate only slots `0..popcount-1`; therefore no real selected-copy expression reaches the spare region beginning at `0x400 + popcount*0x800`. The authentic Bink target has `alloc==popcount==2`, so no synthetic spare-capacity task or spare-region read was added.

### 9. Narrow validation-only diagnostics; no guest-visible bypass

PASS by source review. Expensive work is first-Bink-only; universal instrumentation is limited to arithmetic/bounds checks and fail-stop on impossible/unsafe context geometry. No scheduler, EventFlag, DMA, task-state, readiness, ELF, or resume semantics were bypassed or fabricated.

### 10. Source self-review only

`git diff --check` was run after source changes and passed with no output. No compiler, build, test binary, GTA probe, or runtime was executed. Source review confirmed all diagnostic context reads are preceded by legal-range proof, all neighbor reads are wholly within legal task LS, and the only guest-memory writes in the instrumented copy region remain the four pre-existing real memcpy forms (fixed save, payload save, fixed restore, payload restore).

### 11. Report / future acceptance requirements

This file documents changed symbols, marker schema, acceptance conditions, before/after hashes, source evidence, and future build/runtime requirements. Future commands below are requirements only and were **not** executed.

### 12. Commit / clean worktree

The source patch and this report are to be committed together on `team/prod-spurs-canary-instrumentation`. Post-commit verification must require an empty `git status --short`; the final Lane187 response records the resulting commit SHA.

## Important source geometry evidence

- Compact sizing: `cellSpurs.cpp` current lines 4116-4133.
- Exact Bink pattern predicate: `cellSpurs.cpp` current lines 4140-4146.
- DECODE required-size provenance: `cellSpurs.cpp` current lines 4193-4209.
- Existing alloc derivation/popcount validation: `cellSpurs.cpp` current lines 4256-4274.
- Existing TaskInfo packed publication + CREATE provenance: `cellSpurs.cpp` current lines 4319-4332.
- TaskInfo-derived save base/capacity and fixed-copy guard: `cellSpursSpu.cpp` around current lines 1828-1850.
- Real fixed save memcpy remains `0x380`: immediately after the legal gap-before setup.
- Real compact save memcpy remains `contextSaveStorage + 0x400 + (slot << 11)` with 0x800 bytes inside the selected loop.
- Actual restore is the `isWaiting != 0` `else` branch in `spursTasksetDispatch`; canary logic starts after its existing optional ELF reload.
- Real fixed restore memcpy remains `0x380`.
- Real compact restore memcpy remains `contextSaveStorage + 0x400 + (slot << 11)` with 0x800 bytes inside the selected loop.

(Line numbers in `cellSpursSpu.cpp` can shift slightly with any report-independent source edit; the named symbols and exact copy expressions are authoritative.)

## Future build acceptance command requirement — DO NOT EXECUTE IN LANE187

A future coordinator/reviewer must use a clean checkout of the **committed Lane187 SHA** and the repository-approved production Android `libe.so` build recipe, serialized through the mandatory wrapper:

```sh
cd /data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane187-prod-spurs-canary-instrumentation
~/.local/bin/gd-team-heavy lane187-prod-spurs-canary-build -- <APPROVED_PRODUCTION_ANDROID_LIBE_SO_BUILD_COMMAND>
```

Acceptance requirements:

1. The command inside `gd-team-heavy` must be the already-approved production Android `libe.so` build invocation; **do not invent or substitute a desktop/synthetic target**.
2. Start from the exact committed Lane187 source hashes recorded above.
3. Require build/link RC=0.
4. Record the exact command, toolchain/config identifiers, resulting `libe.so` SHA-256, and source hashes.
5. Build success is only compile/link evidence; it does not authorize install, GTA execution, merge, or playability claims.

The sparse Lane187 worktree contains no authoritative approved production build script/command, and Lane183 did not provide the inner invocation. Therefore this report intentionally does not fabricate an inner command; the coordinator must supply the approved production invocation while preserving the exact wrapper/commit constraints above.

## Future runtime canary command requirement — DO NOT EXECUTE IN LANE187

Only after the instrumented build is independently accepted, a future coordinator must run exactly one approved production-equivalent GTA Bink save/resume validation, serialized through the same global heavy-job wrapper:

```sh
~/.local/bin/gd-team-heavy lane187-prod-spurs-canary-bink -- <APPROVED_PRODUCTION_EQUIVALENT_GTA_BINK_SAVE_RESUME_COMMAND>
```

The exact GTA probe inner command is likewise intentionally not fabricated in this source-only lane because no authoritative invocation was provided in Lane187/Lane183 inputs. The future run must capture the complete native log to a durable file and satisfy **all** of the following for one identical `{taskset,task,context,pattern}` tuple:

```text
DECODE (if v1 decode path is used)
CREATE
SAVE_BEGIN
SAVE_COPY block=57 slot=0 ctx_off=0x400 ctx_end=0xc00 ls_start=0x1c800 ls_end=0x1d000 equal=1
SAVE_COPY block=127 slot=1 ctx_off=0xc00 ctx_end=0x1400 ls_start=0x3f800 ls_end=0x40000 equal=1
SAVE_END popcount=2 slot=2 slot_ok=1 gap_equal=1
...
RESTORE_BEGIN isWaiting!=0
RESTORE_COPY block=57 slot=0 ... equal=1 neighbor_a_block=56 neighbor_a_equal=1 neighbor_b_block=58 neighbor_b_equal=1
RESTORE_COPY block=127 slot=1 ... equal=1 neighbor_a_block=126 neighbor_a_equal=1
RESTORE_END popcount=2 slot=2 slot_ok=1 gap_equal=1
```

Runtime rejection conditions:

- any `SPURS_CANARY_FAIL` marker;
- missing same-identity restore after save;
- any selected block other than 57/127 for the canary tuple;
- wrong slot order;
- any Bink context access starting at/above `+0x1400` or ending beyond it;
- `+0x19c00` or `+0x3cc00` produced for the Bink compact copy loop;
- payload SHA inequality;
- save destination SHA != later restore source SHA for the same slot;
- reserved-gap SHA inequality within save or restore;
- local unsaved-neighbor SHA inequality around a restore memcpy;
- runtime crash/abort before the complete ordered save/resume evidence is captured.

After successful evidence capture, remove **all** Lane187 instrumentation and require the two production source hashes to return exactly to Lane178:

```text
cellSpurs.cpp    318d9d982714fcb2090dd62a0336fb4c134ae64fff32a0de4d2c8bd3b04cb9c2
cellSpursSpu.cpp 5a83d06e6f1e82c94b36459bd69a3141b311a52383d294e271fb109f39b1f1c6
```

Only a separate independent evidence review may then decide whether Lane178 is ready for production integration.

## Disposition

**SOURCE_INSTRUMENTATION_READY_FOR_INDEPENDENT_REVIEW.**

This disposition does not claim that the code compiles or that the runtime canary passes, because both were explicitly outside Lane187 authorization. It authorizes no build, install, GTA run, push, merge, workflow dispatch, or playability claim by itself.
