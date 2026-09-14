# Lane241 — CMake-pinned Android-host build gate v3

## Disposition

**STATIC CORRECTION COMPLETE — NEEDS INDEPENDENT REVIEW BEFORE ANY BUILD.**

Lane241 is based on exact Lane237 commit `d787644dc8c1c5076047dd6b36c8bfff659a85db` and fixes only the CMake-host provenance blocker identified by Lane239. No CMake configure, compile, Ninja, Gradle, build, install, GTA launch, APK/core replacement, cache clearing, protected-data cleanup, or NDK mutation was performed.

## Exact correction

The future wrapper now pins and verifies, before any future configure:

- CMake executable: `/data/data/com.termux/files/usr/bin/cmake`
- version: `4.4.1`
- executable SHA-256: `07c5f6bfdc48dd4f79085438ce4ab4b467313f31c9aadf5125fc3fd69ee0e682`
- `CMakeDetermineSystem.cmake`: `c9a0e1cd987f813b8138039b12f5cdee70f3c7db1534c9853f3ab1c083d2276d`
- `Platform/Android-Determine.cmake`: `e8569c136777626c7252438d0ea57a8089f8fb45de5e0c04dd9583b1239775a3`
- `Platform/Android-Determine-C.cmake`: `1939341111e9b7382f8afcf222e12233235323b43620f2175bf54ef0b45997ce`
- `Platform/Android-Determine-CXX.cmake`: `dfa74e48fe90a5189982784b9d4c1c310f1c257bdb36349b61ece1ad4e5c8164`

Current read-only host identity is `uname -o = Android`, `uname -m = aarch64`. The wrapper requires those exact values and verifies the pinned module text still contains the Android-host early-return and the explicit C/CXX-compiler early returns in the reviewed ordering.

`cmake --system-information` is deliberately not used by the future gate. The installed artifacts do not establish it as a narrower or more side-effect-free probe than the task requires, so Lane241 uses only read-only `uname`, `cmake --version`, exact executable/module hashes, and exact module-flow inspection before configure. This is fail-closed: any host identity or reviewed CMake implementation change requires another review.

Both future configure and future build invoke only the exact absolute pinned CMake path; there is no bare PATH `cmake` invocation.

## Preserved Lane237 gates

Lane241 preserves the Lane237 global `gd-team-heavy` ancestry/flock proof and exact label contract, approved commit/self-hash/Git-blob checks, direct-parent requirement, six-file Lane220 native-source lineage including the `Emu/CMakeLists.txt` Android definition, canonical-source fingerprint, stock r29 source/toolchain/sysroot identities, Termux compiler/tool hashes, host-leak graph checks, artifact checks, fresh build directory, >=4 GiB storage gate, and `--parallel 1`.

Lane241 changes no inherited candidate native source. Its exact parent must be Lane237 `d787644dc8c1c5076047dd6b36c8bfff659a85db`; the launcher independently enforces the same parent and approved script identities.

The historical partial repair NDK tree is not used or mutated. No 325 MB NDK tree is created, copied, or symlinked.

## Static verification performed

- `bash -n LANE241_BUILD_WRAPPER.sh`: PASS
- `bash -n LANE241_CXX_AUDIT_LAUNCHER.sh`: PASS
- exact CMake version/hash/module hashes: PASS
- current host `Android/aarch64`: PASS
- reviewed Android-host early-return text/order: PASS
- explicit C/CXX compiler early-return text/order: PASS
- Lane241 HEAD parent before commit is exact Lane237 base by worktree construction: PASS
- no inherited `app/src/main/cpp` change relative to Lane237: PASS
- no bare configure/build `cmake` invocation remains: PASS
- no configure/build/runtime/protected mutation performed: PASS

Pre-commit script SHA-256 values:

- `LANE241_BUILD_WRAPPER.sh`: `74c0e9e7163f75e60dca1b13a24d150ae7faa2a4f3cc41758acd1a2a1391e2d9`
- `LANE241_CXX_AUDIT_LAUNCHER.sh`: `2b406fd592008160db5716598b9a345b193520b0971fad048ac6f9979fd5d3c0`

## Current execution status

This report does **not** authorize a build. Lane241 must receive an independent static review of the exact committed identity and script hashes before any future heavy attempt. Current `/data` free space is below the mandatory 4 GiB heavy threshold, independently blocking a build.

## Future reviewed invocation

Only after an independent reviewer accepts the exact committed Lane241 identity and current preflights still pass:

```bash
LANE241_APPROVED_COMMIT=<REVIEWED_LANE241_COMMIT> \
LANE241_APPROVED_WRAPPER_SHA256=74c0e9e7163f75e60dca1b13a24d150ae7faa2a4f3cc41758acd1a2a1391e2d9 \
LANE241_APPROVED_LAUNCHER_SHA256=2b406fd592008160db5716598b9a345b193520b0971fad048ac6f9979fd5d3c0 \
~/.local/bin/gd-team-heavy lane241-bink-build-gate-v3 -- \
/data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane241-bink-build-gate-v3/LANE241_BUILD_WRAPPER.sh
```

That invocation is future-only and remains fail-closed on storage, source lineage, CMake/NDK/tool identity, global-heavy ancestry, graph, and artifact gates.
