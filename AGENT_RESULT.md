# Lane 178 — Production SPURS compact context storage correction

Date: 2026-09-12
Branch: `team/prod-spurs-compact-context`
Starting commit: `4689537cb9b1c79738b6e1f0cadd1843f0c02b40` (Lane172)
Scope: source patch + report only. No Codex, build, test execution, GTA probe, APK/NDK action, install, merge, or heavyweight job was performed.

## Result

Implemented the smallest coherent production correction requested by Task178:

1. `cellSpursSpu.cpp` now saves selected task LS blocks into compact ordinal main-memory slots after the fixed `0x400` processor-context area while preserving the absolute LS source address derived from the real selected block number.
2. The restore path uses the identical ascending-block ordinal traversal, so compact save and restore remain symmetric.
3. Lane172's `spurs_task_context_save_area_size()` now returns compact capacity: `0x400 + popcount(pattern) * 0x800`, while still rejecting SPURS management blocks 0..5.
4. The existing Lane172 initializer/decoder capacity checks therefore accept authentic Bink `sizeContext=0x1400` for selected blocks 57+127 and still reject a context smaller than the compact required size.
5. `cellSpursTaskGetContextSaveAreaSize()` now returns that same compact size because it delegates to the corrected helper.
6. No TaskInfo layout, stack-coverage rule, popcount-vs-allocated-count validation, scheduler behavior, EventFlag behavior, DMA semantics, task ABI, or Android application code was changed.

## Exact compact algorithm

### Context size

For a valid task LS pattern:

```text
saved_blocks = popcount(pattern[0..127])
required_size = 0x400 + saved_blocks * 0x800
```

Before counting, any selected management block in LS blocks 0..5 remains invalid (`CELL_SPURS_TASK_ERROR_INVAL`).

This yields the Task178 required vectors by inspection:

- empty pattern -> `0x400`
- block 6 only -> `0xc00`
- blocks 57 + 127 -> `0x1400`
- any three valid selected blocks, including block 127 -> `0x1c00`
- any management block 0..5 selected -> `CELL_SPURS_TASK_ERROR_INVAL`

The v1 attribute initializer and decoder both continue to require `context_size >= required_size`. Because `required_size` is now compact rather than a highest-block sparse span, they accept the authentic Bink descriptor while still rejecting genuinely undersized compact storage.

### Save mapping

Save iterates real LS block numbers in ascending order `i = 6..127`. A separate ordinal `slot` starts at zero and increments only when block `i` is selected.

For each selected block:

```text
LS source      = CELL_SPURS_TASK_TOP + ((i - 6) << 11)
context target = context + 0x400 + (slot << 11)
slot++
```

Thus the selected LS address remains absolute by real block number, while the main-memory payload is compact.

### Restore mapping

Restore performs the same ascending selected-block traversal and ordinal slot sequence:

```text
context source = context + 0x400 + (slot << 11)
LS target      = CELL_SPURS_TASK_TOP + ((i - 6) << 11)
slot++
```

This is the inverse of save without changing the LS pattern or TaskInfo representation.

## Authentic GTA Bink geometry

The authenticated Bink pattern is:

```text
00000000 00000040 00000000 00000001
```

Selected blocks: `57`, `127`

Popcount: `2`

Compact required size:

```text
0x400 + 2 * 0x800 = 0x1400
```

Expected mapping after this correction:

- block 57 LS range `0x1c800..0x1cfff` <-> context `+0x400..+0xbff` (slot 0)
- block 127 LS range `0x3f800..0x3ffff` <-> context `+0xc00..+0x13ff` (slot 1)

The final selected-block byte therefore ends at `context+0x13ff`; there is no selected-LS payload write at or beyond `context+0x1400` for this two-block Bink allocation.

The existing creation contract is preserved:

```text
alloc_ls_blocks = (0x1400 - 0x400) >> 11 = 2
popcount(pattern) = 2
TaskInfo low allocated-block count = 0x02
```

No reinterpretation of `context_save_storage_and_alloc_ls_blocks` was introduced.

## Preserved production behavior

The following behavior was intentionally left unchanged:

- processor context copy remains at context base, with the existing `0x380` copy;
- stack-coverage validation still requires the saved SP through block 127 to be represented in the LS pattern;
- `lsBlocks > allocLsBlocks` remains a task state error;
- management LS blocks 0..5 remain invalid for task save patterns;
- the LS pattern remains the mapping metadata;
- TaskInfo keeps the low-seven-bit allocated-block count;
- the private Lane172 v1 attribute layout and exact six-argument `_cellSpursTaskAttributeInitialize` ABI are unchanged;
- task creation still delegates to `_spurs::create_task()` and then existing `_spurs::task_start()`;
- scheduler, EventFlag, reservation, workload, DMA-wait semantics, and unrelated SPURS paths were not touched;
- inherited private production snapshot changes predating Lane172 were not rewritten.

## Test-source decision

No suitable existing aPS3e/RPCS3 unit-test harness was found under this repository's `app/src` or nearby repository test layout during bounded source inspection. Task178 explicitly forbids inventing a large framework, so no new test framework or standalone executable was added.

A follow-up validation lane should exercise at minimum:

1. size helper: empty -> `0x400`;
2. size helper: block6 -> `0xc00`;
3. size helper: blocks57+127 -> `0x1400`;
4. size helper: three valid blocks including127 -> `0x1c00`;
5. size helper/initializer: management block0..5 -> `CELL_SPURS_TASK_ERROR_INVAL`;
6. initializer/decoder: Bink size `0x1400`, blocks57+127 -> accept;
7. initializer/decoder: same two-block pattern with context smaller than `0x1400` -> reject;
8. save: blocks57+127 write only context slots `+0x400` and `+0xc00`, with a canary immediately after `+0x13ff` unchanged;
9. restore: compact slots roundtrip exactly back to LS blocks57 and127, with unsaved neighbors unchanged;
10. TaskInfo: Bink packed allocated-block count remains `2`.

No compile or test execution was performed in this lane, by instruction.

## Source-only validation

`git diff --check` passed after the source patch.

The intended modified source scope is only:

- `app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpurs.cpp`
- `app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpursSpu.cpp`
- `AGENT_RESULT.md`

## Remaining ABI uncertainty

Lane177 established the compact contract for the production-relevant GTA Bink path from the retail title's own size calculation/allocation sequence, its actual SPU ELF-derived pattern, live TaskInfo state, and aPS3e's allocated-block-count creation contract.

A locally cached `task.h` declares the Sony-era API shape but does not document the size formula and lacks independent provenance sufficient to claim universal Sony-library behavior. Therefore this patch does **not** claim that every historical Sony implementation of `cellSpursTaskGetContextSaveAreaSize()` used this exact formula in every circumstance.

That universal-ABI uncertainty is separate from the production bug corrected here. For the authenticated GTA path, retaining sparse absolute main-memory offsets would overflow the title's actual compact allocation. Old RPCS3's longstanding sparse save/restore behavior is therefore not reintroduced merely as precedent.

## Disposition

Source correction is ready for the separately required independent review. It has not been merged, built, installed, or runtime-tested. A reviewer must approve the combined Lane172 bridge + Lane178 compact saver/size correction before any focused compile/test or Android integration work.
