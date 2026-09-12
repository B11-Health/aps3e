# Lane196 — canary libe build wrapper v3 host-header isolation correction

Date: 2026-09-12
Branch: `team/prod-spurs-canary-build-wrapper-v3`
Base: Lane193 corrected wrapper lineage at `6b1a3b567b76b7b4e60797b15891c675dc6d6a75`
Scope: source/script + report only. No wrapper execution, CMake configure, compile, Ninja, GTA, APK/NDK build, install, push, merge, cleanup, deletion, or canonical/Lane187 mutation performed in this lane.

## Final disposition

**READY_FOR_FRESH_INDEPENDENT_REVIEW**

Lane195 verified that Lane193 v2 closes the 13 Lane191 structural/safety blockers but found one additional deterministic blocker from real build evidence: Android LLVM inherited `-isystem /data/data/com.termux/files/usr/include`, causing NDK libc++ to resolve Termux host C headers and fail in `LLVMSupport/AMDGPUMetadata.cpp.o`.

Lane196 preserves the Lane193 v2 safety architecture and makes only the correction required by that evidence.

## Corrections

- New immutable Lane196 worktree/script identity: `LANE196_BUILD_WRAPPER.sh` and `LANE196_OVERLAY_CXX_LAUNCHER.sh`, with matching `LANE196_APPROVED_*` contract and Lane196 trace namespace.
- New never-used build path `$HOME/.cache/gd-prod-spurs-lane187-canary-build-v3`; refuses both the retired non-v2 path and the prior v2 path.
- Retains exact `cmake --build "$BUILD" --target emu --parallel 1`.
- Adds configure-time isolation: `LLVM_ENABLE_ZSTD=OFF`, `LLVM_ENABLE_BACKTRACES=OFF`, `LLVM_ENABLE_LIBEDIT=OFF`, `LLVM_ENABLE_LIBXML2=OFF`.
- Adds exact semantic CMakeCache validation requiring all four values `OFF`.
- Requires generated `CMakeFiles/rules.ninja` and rejects `-isystem $PREFIX/include` in either `build.ninja` or `rules.ninja` before compilation.
- Records `host_include_leak=0` only after both graph checks pass.

## Preserved v2 guarantees

Exact approved commit/SHA/blob provenance, exact Lane187/canonical/NDK pins, repeated `/data >= 4194304 KiB` gates, strict CMakeCache validation, exact `build emu: phony libe.so` proof, strict six-field two-TU overlay trace, recursive unique root `libe.so`, `readelf` ELF64/DYN/AArch64 authority, truthful configure/build RCs and final-state evidence, no-clobber restricted evidence, canonical/Lane187 read-only behavior, no network/install/GTA/internal-heavy action, and parallelism 1 are retained.

## Execution gate

This lane performs static checks only. A fresh independent review must approve the exact final Lane196 commit and exact wrapper/launcher SHA-256/blob identities before the coordinator releases the heavy guard and authorizes exactly one compile/link-only build.
