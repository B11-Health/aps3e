# Lane198 — production SPURS canary build wrapper v4 fail-closed graph correction

Date: 2026-09-12
Branch: `team/prod-spurs-canary-build-wrapper-v4`
Base: exact Lane196 reviewed candidate `d2ccda31532bd1884c463278ae0d75d227007555`
Scope: source/script + report only. No wrapper execution, CMake configure, compile, Ninja, tests, GTA, APK/NDK build, install, push, merge, cleanup, deletion, or canonical/Lane187 mutation.

## Purpose

Lane197 commit `761fbddb5f8c1f3bce8da2470a9cfc8e933695f7` rejected Lane196 because the generated-graph host-include checks used `if grep ... || grep ...`, which treated `grep` rc>1 like ordinary no-match and could record `host_include_leak=0` without proving absence.

Lane198 performs only the already-directed correction while preserving Lane196 v3 protections.

## Exact correction

- Fresh immutable worktree/script identity: `LANE198_BUILD_WRAPPER.sh`, `LANE198_OVERLAY_CXX_LAUNCHER.sh`, and `LANE198_APPROVED_*` execution contract.
- Fresh never-used build path: `$HOME/.cache/gd-prod-spurs-lane187-canary-build-v4`.
- For both `build.ninja` and `CMakeFiles/rules.ninja`, and for both forbidden forms `-isystem $PREFIX/include` and `-I$PREFIX/include`, each grep now has explicit semantics:
  - rc 0 => forbidden host include detected, fail closed;
  - rc 1 => verified absence, continue;
  - rc >1 => inspection error, fail closed.
- Existing leak failures remain distinct (`151` build.ninja, `152` rules.ninja); inspection errors use `153` and `154`.
- `host_include_leak=0` is emitted only after all four checks return verified absence.

## Preserved protections

The Lane196 architecture remains intact: exact commit/SHA/blob provenance, exact Lane187/canonical/NDK pins, four LLVM host-isolation settings with strict cache assertions, generated graph validation before build, repeated >=4194304 KiB storage gates, exact `build emu: phony libe.so` proof, strict overlay trace, root `libe.so` uniqueness, ELF64/DYN/AArch64 authority, truthful per-stage RC/final-state evidence, canonical/Lane187 read-only behavior, no network/install/GTA/internal-heavy action, and `cmake --build "$BUILD" --target emu --parallel 1`.

## Static checks

PASS:

- `bash -n LANE198_BUILD_WRAPPER.sh LANE198_OVERLAY_CXX_LAUNCHER.sh`
- `git diff --check`
- both scripts remain executable mode 0700
- no stale Lane196/LANE196/lane196 or v3 worktree/build-path strings remain in the two scripts
- wrapper SHA-256: `75fd30497a9d718e71ea9554737dba424745a08f4cac34a95e88ee22be67ff0c`
- launcher SHA-256: `6b26c24fddacbef4bb70e3503c5aeb0ec68f981119d37e9232e3cd0c0000dc36`

## Limitations / gate

This is static correction evidence only. It does not establish configure/build/link success, production correctness, GTA runtime correctness, Story Mode, gameplay, audio, frame pacing, or playability.

A fresh independent review must approve the exact committed Lane198 identity and exact wrapper/launcher SHA/blob identities before the coordinator may release the heavy guard or authorize one serialized compile/link-only run.

**READY_FOR_FRESH_INDEPENDENT_REVIEW**
