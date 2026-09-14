# Lane237 — Bink PUTLLC diagnostic build gate v2

## Disposition

**ACCEPT FOR ONE FUTURE SERIALIZED BUILD GATE, CONDITIONALLY.**

This is a static/script review result only. Lane237 was not configured, compiled, built, installed, or run. GTA was not launched. No protected GTA content, BLUS31156/TU data, firmware, saves, emulator configuration, PPU/SPU/shader/Vulkan caches, or QA evidence was changed or deleted.

The future build is authorized only after an independent reviewer supplies the exact committed Lane237 identity and script hashes shown by the reviewed commit, invokes it through the exact global `gd-team-heavy` label/contract below, and all fail-closed runtime preflights pass. Current storage does **not** pass the wrapper's 4 GiB floor, so this report is not authorization to execute a build now.

## Exact base and lineage

Lane237 is based on exact Lane230 HEAD:

- Lane230: `d774c1af0a45c10ba7726b73ab634f91609838a7`
- Reviewed Lane220 ancestor: `46679d67d140a59599ae43ba5f2efb5597d6e743`
- Canonical production source HEAD pinned by the wrapper: `7dc95e6baaac0712d5b3c28501778dd7934e579b`
- Canonical status fingerprint pinned by the wrapper: `3381452a0a288719e1056a5a7bce2f624bef99fde054387253a276fc43587d66`

Static ancestry check: Lane220 is an ancestor of Lane230 (`git merge-base --is-ancestor` returned 0).

Relative to canonical `7dc95e6...`, the candidate native-source divergence is exactly the reviewed Lane220 six-file lineage:

1. `Emu/CMakeLists.txt` — modified
2. `Emu/Cell/Modules/cellSpurs.cpp` — modified
3. `Emu/Cell/Modules/cellSpursSpu.cpp` — modified
4. `Emu/Cell/SPULLVMRecompiler.cpp` — modified
5. `Emu/Cell/SPUThread.cpp` — modified
6. `Emu/Cell/spurs_live_canary.h` — added

Lane237 does not edit those inherited candidate source files. Its future configure uses the isolated Lane237 source tree directly, so the Lane220 `Emu/CMakeLists.txt` change is consumed instead of configuring canonical source and substituting only selected translation units.

Pinned candidate SHA-256 values verified statically:

- `Emu/CMakeLists.txt`: `22927b0d3f0332b8fa26ea18dd2c1d3eab8a25a2848195acd13ef261b858c97d`
- `cellSpurs.cpp`: `0069fcba05a009b93663006d0d9047521ec6b2fe465ee0c55aea8f70c957305d`
- `cellSpursSpu.cpp`: `f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570`
- `SPULLVMRecompiler.cpp`: `2d6b4fa079d5721bb96dab46395cc189096c58b7088877fc134cc6d2cb124009`
- `SPUThread.cpp`: `2979bb64cdcf34e540279b72282f08a250e1db0103f557cab9313d6c52914bc0`
- `spurs_live_canary.h`: `69982b9d1a12e87cbe94954b92487f6122b213cec24b40d08ea30851f5f01c8a`

The candidate `Emu/CMakeLists.txt` contains exactly one `target_compile_definitions(rpcs3_emu PUBLIC ANDROID)`, preserving the Android runtime macro lineage that Lane230's canonical-source configure dropped.

## BINK_PUTLLC_CANARY scope

Lane237 retains the already independently reviewed Lane220 `BINK_PUTLLC_CANARY`; it does not alter that instrumentation. The canary remains restricted to Bink SPU `lv2_id == 0x03000100`, keeps three diagnostic `thread_local u64` counters, records the first 16 attempts and then one per 8192 attempts, and leaves the original PUTLLC result body and downstream success/failure behavior intact. The sampled `spu_log.notice` can slightly perturb sampled timing but is bounded and remains diagnostic only, not a gameplay fix.

The future artifact gate requires exactly one `BINK_PUTLLC_CANARY` string in `libe.so`.

## Global heavyweight contract is now mandatory

Reviewed guard:

- `~/.local/bin/gd-team-heavy`
- SHA-256: `5f76d17fcf85469d2bdcfb2c63c632bab4583a8392263ddac3c5d940b3c35001`

The guard opens `~/.cache/gd-team-heavy.lock` on fd 9, acquires it with `flock 9`, writes `pid=<guard-pid> label=<label> started=<timestamp>` to `~/.cache/gd-team-heavy.state`, and then runs the requested command beneath that guard process.

`LANE237_BUILD_WRAPPER.sh` now fails closed unless all of the following are true before any configure step:

- the guard file exists, is executable, is not a symlink, and has the exact reviewed SHA-256;
- the state file exists and parses as the reviewed three-token contract;
- the active state label is exactly `lane237-bink-putllc-build-v2`;
- the recorded guard PID is live and its command line identifies `gd-team-heavy`;
- the guard PID's fd 9 resolves to the expected global lock file;
- that guard PID is an actual ancestor of the Lane237 wrapper process;
- an independent nonblocking `flock` attempt confirms the global lock is actually held.

Therefore `--parallel 1` is no longer confused with global serialization. The global lock is mandatory first; `--parallel 1` additionally serializes the build internals.

## Candidate provenance / immutable reviewed identity

The future wrapper requires the reviewer to supply:

- `LANE237_APPROVED_COMMIT` — exact 40-hex reviewed Lane237 commit;
- `LANE237_APPROVED_WRAPPER_SHA256` — exact reviewed wrapper SHA-256;
- `LANE237_APPROVED_LAUNCHER_SHA256` — exact reviewed launcher SHA-256.

Current pre-commit script SHA-256 values are:

- `LANE237_BUILD_WRAPPER.sh`: `d1790c64d6afaca43cf2b0d8c877ee7d8783a18074b4978f20bd51afb6c44887`
- `LANE237_CXX_AUDIT_LAUNCHER.sh`: `a6af86b92f1b737a66c6ff0dbee59bf3e39676d8a10dd281e3dc508dac3a398a`

The wrapper then verifies that its worktree is clean, branch name is exact, HEAD equals the approved commit, HEAD has exactly one parent and that parent is Lane230 `d774c1af...`, Lane220 remains an ancestor, both scripts match their approved Git blobs and SHA-256 values, and the native-source divergence remains exactly the six reviewed Lane220 files. The launcher independently repeats the approved commit, parent, wrapper hash, launcher hash, and Git-blob checks before invoking the compiler.

## Static NDK/toolchain proof

### Current full NDK

Lane230's hard-coded `~/android-sdk/ndk-r29-arm64-local` no longer exists. Lane237 instead pins the existing full tree:

`~/android-sdk/ndk-r29-local`

Verified current identities:

- `source.properties` SHA-256: `716f3518a923198cfab037abb32dc3f1b1f7e9a9dcdcda6b66be5906215d2658`
- revision: `Pkg.Revision = 29.0.14206865`
- stock `build/cmake/android.toolchain.cmake` SHA-256: `dbad92d9dcfea0d32b7c5e5f82f5072d878ded5d46a5d3f1f581ea108ca7fe89`

The old partial `~/.ndk-r29-local-repair-20260914/android-ndk-r29` tree is currently absent and is intentionally not referenced. Lane237 does not recreate, copy, symlink, or mutate a replacement NDK tree.

### Why the existing stock toolchain + full sysroot arrangement is coherent on Termux

The stock r29 toolchain is used with `ANDROID_USE_LEGACY_TOOLCHAIN_FILE=OFF`, explicit `ANDROID_NDK=~/android-sdk/ndk-r29-local`, explicit Termux `CMAKE_C_COMPILER=/data/data/com.termux/files/usr/bin/cc`, explicit Termux `CMAKE_CXX_COMPILER=/data/data/com.termux/files/usr/bin/c++`, and the full NDK sysroot.

Static CMake/toolchain evidence:

1. The stock r29 toolchain derives `ANDROID_HOST_TAG` only for Linux/Darwin/Windows and then forms `${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt/${ANDROID_HOST_TAG}` and `CMAKE_SYSROOT=${ANDROID_TOOLCHAIN_ROOT}/sysroot`.
2. Existing prior CMake metadata on this device records `CMAKE_HOST_SYSTEM_NAME "Android"`, `CMAKE_HOST_SYSTEM_PROCESSOR "aarch64"`.
3. Therefore on this Termux host the resulting toolchain sysroot spelling is the already-observed `.../toolchains/llvm/prebuilt//sysroot`.
4. The current full NDK has an existing compatibility symlink `toolchains/llvm/prebuilt/sysroot -> linux-x86_64/sysroot`; Lane237 verifies both its literal target and its resolved destination before configure.
5. CMake 4.4's `Platform/Android-Determine-C.cmake` returns immediately when `CMAKE_C_COMPILER` is already specified; `Android-Determine-CXX.cmake` does the same for `CMAKE_CXX_COMPILER`. Thus Lane237's explicit Termux compilers avoid any requirement to execute absent x86_64 NDK clang binaries.
6. The prior `~/.cache/lane230-ndk-smoke/build3` evidence independently shows the exact architecture of this arrangement: generated rules invoke `/data/data/com.termux/files/usr/bin/c++ --sysroot=.../toolchains/llvm/prebuilt//sysroot`; compiler metadata records Termux `cc/c++` and Termux `llvm-ar/llvm-ranlib`; configure completed; build completed; and the resulting `libndk_smoke.so` is `ELF 64-bit ... ARM aarch64 ... for Android 24, built by NDK r29 (14206865)`.

The smoke artifact SHA-256 is `071b9fa70d3c7b38120c2a2263c867234c238c245257dcf2c2787580222d3cc9`. It is historical evidence only; Lane237 did not rerun it.

### Existing compatibility/sysroot corrections are pinned, not modified

Lane237 verifies the pre-existing compatibility links and files before any future configure. Relevant pinned identities include:

- API-24 `libunwind.a`: `c52c8462134a1610e93d873e9d992f4804027d0c73115b2ea4c21b0aed5cbe65`
- API-24 `libz.so`: `1399497eaea6e1dd0e9e8e13439890e8ca9695bbd801e1085e945e207a00aaa6`
- API-24 `libvulkan.so`: `f0906b4f9f4e67e1d0078a737f7fe466ce4a239b028cbfdb9256ea320670b43b`
- Termux `cc`/`c++`: `3599a121ecc11b433d23bc43545bc0441f9a8ffcc587ea18e312d88188fcf282`
- Termux `ld.lld`: `7a0e3dad3eaeaf7ec0e85337ab1047470141e95aae11e4b51eb12c749c1a561a`
- Termux `llvm-ar`/`llvm-ranlib`: `a43266eaab0bbd4eabf2127f796015c46897044748bcc50976421fc116f37798`
- Termux `llvm-strip`: `b1196f21e347a912662b0bea76ad97c60f758e68c612b58006d505182a679392`

No installed NDK file or link was created or changed by Lane237.

## Future graph/artifact fail-closed gates

After a future configure only if all earlier preflights pass, the wrapper requires:

- CMake home directory is the isolated Lane237 source tree;
- CMake cache names the pinned stock r29 toolchain;
- generated compiler identities are the pinned Termux `cc/c++`;
- candidate `Emu/CMakeLists.txt` appears in the regeneration graph;
- generated graph contains the Lane220 `-DANDROID` definition;
- generated rules use the pinned full-NDK sysroot (`prebuilt//sysroot` alias or its resolved path);
- no stale `ndk-r29-arm64-local`, partial repair tree, Termux target include/library path, or forbidden versioned host library leaks into the target graph;
- build target remains `emu --parallel 1`;
- CXX audit sees each of the four critical Lane220 translation units exactly once and rejects canonical copies;
- final `libe.so` is AArch64, has no RPATH/RUNPATH or forbidden runtime dependency, and contains exactly one `BINK_PUTLLC_CANARY` string.

## Current resource state

At this review, `/data` free space is `3,398,456 KiB`. Lane237 requires at least `4,194,304 KiB` before creating its build/run directories. Therefore the future wrapper would fail closed today at the storage gate even if all identity and heavyweight-lock checks passed.

Protected GTA assets must not be deleted to satisfy that threshold.

## Runtime policy remains fail-fast

A later runtime test is a separate authorization. If an independently reviewed built artifact is ever staged, the startup bikini/SPU/PPU phase must be allowed to complete normally. Once the transition reaches the real failure window, capture only enough `BINK_PUTLLC_CANARY` evidence to classify repeated EA/cache-line behavior and success/failure ratio, then immediately force-stop GTA. Do not soak a black screen or leave the phone heating.

## Static checks performed in Lane237

Only static/read-only checks were run apart from writing these Lane237 artifacts:

- `bash -n` on both scripts: PASS.
- candidate source SHA-256 checks: PASS.
- guard/toolchain/tool SHA-256 checks: PASS.
- exact canonical-to-candidate six-file native diff check: PASS.
- Lane220 -> Lane230 ancestry check: PASS.
- prior smoke logs/cache/rules/artifact inspected read-only: PASS as historical evidence.
- no CMake configure, Ninja, compile, Gradle, install, GTA runtime, cache clearing, or protected-data mutation was performed.

## Future reviewed invocation

After this Lane237 commit receives independent review, substitute the exact committed SHA for `<LANE237_COMMIT>` and use the exact script hashes from this report/commit:

```bash
LANE237_APPROVED_COMMIT=<LANE237_COMMIT> \
LANE237_APPROVED_WRAPPER_SHA256=d1790c64d6afaca43cf2b0d8c877ee7d8783a18074b4978f20bd51afb6c44887 \
LANE237_APPROVED_LAUNCHER_SHA256=a6af86b92f1b737a66c6ff0dbee59bf3e39676d8a10dd281e3dc508dac3a398a \
~/.local/bin/gd-team-heavy lane237-bink-putllc-build-v2 -- \
/data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane237-bink-putllc-build-v2/LANE237_BUILD_WRAPPER.sh
```

That invocation is **future-only** and still must fail closed if storage, canonical identity, NDK/sysroot/tool hashes, global lock ancestry, source lineage, or any other gate has changed.
