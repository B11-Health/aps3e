# Lane 172 — Production aPS3e SPURS task-attribute API bridge

Date: 2026-09-12
Branch: `team/prod-spurs-api`
Base: `97c8df684c2572b97623c8d0a4d98ce86d40257f`
Scope: source patch + report only. No build, unit test, GTA probe, APK/NDK job, install, or other heavyweight job was run.

## Result

Implemented the three production `cellSpurs.cpp` exports identified by Lane170 as the genuine Android parity gap, without changing the public opaque `CellSpursTaskAttribute` ABI and without copying clean-room scheduler/TaskInfo/EventFlag logic:

1. `cellSpursTaskGetContextSaveAreaSize`
2. `_cellSpursTaskAttributeInitialize`
3. `cellSpursCreateTaskWithAttribute`

`cellSpursCreateTaskWithAttribute` is an adapter only. After decoding/validating the private v1 attribute it delegates to the existing production `_spurs::create_task()` and `_spurs::task_start()` path, so task-id allocation, `TaskInfo` packing, pending-ready publication, workload signaling, reservations, and wake behavior stay owned by existing production code.

## Authority and ABI assumptions

The task-mandated `/data/data/com.termux/files/home/projects/android/TEAM_RESOURCE_POLICY.md` path does not exist on this device. I verified that absence and read the available project policy at `../gamedeck-ps3-live-lanes-20260908/TEAM_RESOURCE_POLICY.md`; this lane remained source-only, so no heavyweight slot was used.

Lane170 `AGENT_RESULT.md`, local production `cellSpurs.h` / `cellSpursSpu.cpp`, the local Sony-identifying `~/.cache/gd-spurs-ref/task.h`, the GTA 1.06 caller evidence summarized by Lane115, and the local host-native SPURS reference agree on the relevant contract:

- SDK prototype for the size helper is `cellSpursTaskGetContextSaveAreaSize(uint32_t *size, const CellSpursTaskLsPattern *lsPattern)`.
- SDK prototype for the v1 initializer has six arguments: attribute, revision, SDK version, ELF EA, `CellSpursTaskSaveConfig*`, optional `CellSpursTaskArgument*`.
- GTA passes `r7` as a 12-byte big-endian save-config descriptor, not as a raw LS pattern:
  - `+0x00`: context EA (BE32)
  - `+0x04`: context size (BE32)
  - `+0x08`: LS-pattern EA (BE32)
- Proven GTA worker values include context EA `0x104acb00` / `0x104ae000`, size `0x1400`, and LS-pattern EA `0x01e6db10` / `0x01e6db20`; revision is 1, SDK is `0x00330000`, ELF is `0x01bf0f80`, and the optional task argument is null.
- The private v1 attribute view remains local to `cellSpurs.cpp` and overlays the public opaque 256-byte `CellSpursTaskAttribute`:
  - `+0x00` revision BE32
  - `+0x04` SDK version BE32
  - `+0x08` ELF EA BE64
  - `+0x10` context EA BE64
  - `+0x18` context size BE32
  - `+0x1c` reserved
  - `+0x20` 16-byte `CellSpursTaskLsPattern`
  - `+0x30` 16-byte `CellSpursTaskArgument`
  - `+0x40` exit-code-container EA BE32
  - remaining bytes reserved
- Static assertions keep the private view at the same 256-byte size and 16-byte alignment as the public opaque type. `CellSpursTaskAttribute2` was not changed or reused as a v1 layout.

## Context-save geometry

Production `cellSpursSpu.cpp` saves the fixed processor context first and then LS block `N` at:

`context + 0x400 + ((N - 6) << 11)`

for selected blocks `N = 6..127`, with 0x800 bytes per LS block. Therefore the minimum save area is:

- empty LS pattern: `0x400`
- otherwise: `0x400 + (highest_selected_block - 5) * 0x800`

The new helper uses that sparse absolute-span geometry rather than popcount. It rejects management LS blocks 0..5 (`word0 & 0xfc000000`). Examples implied by the implementation are block 6 -> `0x0c00`, block 7 -> `0x1400`, and block 127 -> `0x3d400`.

## Validation added

### `cellSpursTaskGetContextSaveAreaSize`

- null output or LS-pattern pointer -> `CELL_SPURS_TASK_ERROR_NULL_POINTER`
- misaligned output or 16-byte LS-pattern pointer -> `CELL_SPURS_TASK_ERROR_ALIGN`
- management blocks 0..5 selected -> `CELL_SPURS_TASK_ERROR_INVAL`
- writes the sparse-span required size only after validation succeeds

### `_cellSpursTaskAttributeInitialize`

- requires non-null attribute and ELF
- requires 16-byte attribute/ELF alignment, natural save-config alignment, and 16-byte optional argument alignment
- requires v1 revision and nonzero SDK version
- decodes the 12-byte save-config descriptor as context EA / size / LS-pattern EA
- uses the same SDK alignment split already present in production `_spurs::create_task`: context is 16-byte aligned before SDK `0x27ffff`, otherwise 128-byte aligned
- when context is present, requires a non-null 16-byte-aligned LS-pattern pointer, minimum 0x400 fixed context, no management blocks, and a declared context size large enough to cover the highest selected sparse LS block
- when context is absent, rejects nonzero size or LS-pattern EA
- zeroes the full 256-byte opaque attribute before writing v1 fields, so reserved bytes and the exit-code-container field start at zero
- copies the actual 16-byte LS pattern, not the 12-byte descriptor
- copies the optional task argument when supplied; a null argument leaves the zeroed 16-byte argument field intact, matching GTA's observed `r8=0`

### `cellSpursCreateTaskWithAttribute`

- validates taskset, task-id output, and attribute pointers/alignment
- validates revision, SDK, 32-bit-representable ELF/context EAs, ELF alignment, context alignment/size, management-block exclusion, and sparse-span capacity from the private v1 attribute
- builds guest pointers to the embedded v1 LS pattern and task argument
- calls existing `_spurs::create_task()` and then `_spurs::task_start()`; no raw TaskInfo/bitmap/scheduler/EventFlag mutation was added

For GTA's observed `sizeContext=0x1400`, the existing production packing remains authoritative: `_spurs::create_task()` derives two allocated LS blocks and packs `context EA | 2`, e.g. `0x104acb02`, instead of the previous zero context metadata produced by the stub path.

## Files changed

Intended files only:

- `app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpurs.cpp`
- `AGENT_RESULT.md`

No public header, `cellSpursSpu.cpp`, EventFlag implementation, generic SPU opcode path, Android/JNI glue, protected asset, configuration, or production worktree was changed.

## Risks / follow-up

- No compilation or runtime validation was performed because Task172 explicitly prohibits builds/tests/probes. The source was limited to local conventions and checked with `git diff --check`.
- The private v1 byte layout is intentionally isolated because public RPCS3 exposes v1 as opaque. It is supported by the local SDK declaration, GTA caller reconstruction/live descriptor evidence, and local host-native reference, but should remain private until an upstream/public ABI type is authoritative.
- `_spurs::create_task()` still contains its historical popcount-based internal LS allocation validation. This lane does not rewrite that function; the v1 decoder now performs the stricter sparse-span capacity validation before delegating, while the standalone size helper exposes the correct sparse span.
- Invalid-but-mapped guest-address probing is not added; pointer handling follows the existing production RPCS3 convention of explicit null/alignment/semantic checks with guest dereference through `vm::ptr`/`vm::cptr`.
- The v1 exit-code-container field is zero-initialized but `cellSpursTaskAttributeSetExitCodeContainer` is outside Task172 scope and remains unchanged.

## Recommended focused tests for the authorized validation lane

1. Size helper vectors: empty -> `0x400`; only block 6 -> `0xc00`; only block 7 -> `0x1400`; only block 127 -> `0x3d400`; sparse block 6 + 127 -> `0x3d400`; any block 0..5 -> `INVAL`; null/misaligned pointers -> matching SPURS task errors.
2. Initializer byte-layout test with GTA-shaped descriptor: verify revision/SDK/ELF/context/size offsets, copied LS-pattern bytes, zeroed reserved bytes, and zero task argument when argument is null.
3. Initializer negative cases: revision != 1, SDK 0, null/misaligned ELF, misaligned save-config, old/new-SDK context alignment, missing/misaligned LS pattern, management block selection, no-context inconsistency, and context size below sparse required span.
4. Create-with-attribute adapter test: confirm `_spurs::create_task()` receives the decoded ELF/context/size/pattern/argument and existing task-start semantics publish the task exactly once.
5. GTA Bink integration after a permitted build: verify both worker attributes retain `0x104acb00` / `0x104ae000` context storage, TaskInfo packed context is nonzero (first worker expected `0x104acb02` for `0x1400`), blocking receive no longer returns `CELL_SPURS_TASK_ERROR_STAT` because context storage was discarded, and no EventFlag semantics change is needed.
