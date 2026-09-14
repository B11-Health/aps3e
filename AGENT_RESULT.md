# Lane230 — Bink PUTLLC diagnostic build lane

## Scope
Build-only successor for reviewed Lane220 commit `46679d67d140a59599ae43ba5f2efb5597d6e743`. It overlays only the reviewed Bink PUTLLC instrumentation in `SPUThread.cpp` onto the canonical production native graph. No guest/SPU semantics, PPU, SPURS, RSX, Bink decoder, audio, config, cache, save, firmware, or GTA content mutation is introduced here.

## Pinned source
- Candidate `SPUThread.cpp` SHA-256: `2979bb64cdcf34e540279b72282f08a250e1db0103f557cab9313d6c52914bc0`.
- Canonical `SPUThread.cpp` SHA-256: `54d38ae502dfc82b9ff74c218947fec6c86b07cda8891ab008c7cc00306db121`.
- Canonical HEAD: `7dc95e6baaac0712d5b3c28501778dd7934e579b`.
- Canonical status fingerprint: `3381452a0a288719e1056a5a7bce2f624bef99fde054387253a276fc43587d66`.

## Build safety
`LANE230_BUILD_WRAPPER.sh` fails closed unless free `/data` space is >= 4,194,304 KiB, the official r29 toolchain file hash is exact, API-24 zlib/Vulkan stubs exist in the Android sysroot, canonical identities are unchanged, and this worktree is clean. Configure explicitly uses Termux `cc/c++` as host executables while target dependency discovery is rooted in the NDK sysroot. Generated Ninja files are rejected if Termux include/library paths or known host/versioned libraries leak into the Android target graph. Build is serialized with `--parallel 1`.

The resulting `libe.so` must be AArch64, contain exactly one SPUThread overlay trace event, have no RPATH/RUNPATH, and contain none of the explicitly forbidden Termux/Linux runtime dependencies. Passing this lane is only build provenance; it does not claim runtime correctness or playability.

## Runtime policy after a separately verified stage
Do not soak a black screen. Cold launch, allow the normal bikini/SPU/PPU loading phase, then capture only enough `BINK_PUTLLC_CANARY` lines to classify PUTLLC behavior and immediately force-stop the QA package. Analysis/fix happens offline.

## Correction: preserve complete Lane220 SPURS/MFC lineage
Before build execution, a static lineage audit showed that overlaying only `SPUThread.cpp` on canonical HEAD would drop the production SPURS functional port. The build overlay now substitutes exactly four Lane220 source TUs: `cellSpurs.cpp`, `cellSpursSpu.cpp`, `SPULLVMRecompiler.cpp`, and `SPUThread.cpp`, and supplies the hash-pinned `spurs_live_canary.h`. This preserves v1 task-attribute bridging, compact context storage, the non-perturbing live-MFC observer, and the PUTLLC canary together. No incorrect one-TU core was built or installed.
