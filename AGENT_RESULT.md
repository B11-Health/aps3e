# Lane245 — CMake/NDK check-near-use build gate v4

## Result

**STATIC CORRECTION COMPLETE — NOT BUILD AUTHORIZATION.**

Lane245 is a script-only successor to exact Lane241 commit `b2d9b893aaf546b7fa65cc07a094ea11f71800d9`. It addresses the exact TOCTOU blocker identified by independent Lane243 review commit `f705089bfef164f4519b91ac7c4cb6bdd08b2da5`. No configure, compile, Ninja build, Gradle, install, GTA launch, NDK mutation, cache clear, or protected-data mutation was performed.

New v4 files:

- `LANE245_BUILD_WRAPPER_V4.sh`
- `LANE245_CXX_AUDIT_LAUNCHER_V4.sh`

The Lane241 v3 scripts remain unchanged for provenance.

## TOCTOU correction

`LANE245_BUILD_WRAPPER_V4.sh` factors mutable critical identity checks into `verify_critical_identity()` and invokes it three times in the same wrapper process:

1. `critical_identity_preflight` — before any build-tree/run-directory creation;
2. `critical_identity_preconfigure` — immediately before the absolute pinned CMake configure invocation;
3. `critical_identity_prebuild` — immediately before the absolute pinned CMake `--build` invocation.

The function revalidates the approved wrapper and launcher hashes, exact HEAD/branch/parent/clean state, the six reviewed Lane220 native files and Android macro, canonical source identity, exact CMake executable/version/four platform-module hashes and host-flow semantics, Android/aarch64 host identity, full r29 source/toolchain/sysroot alias, NDK compatibility links, Termux compiler/binutils hashes, and the pinned unwind/zlib/Vulkan target libraries.

The semantic CMake check explicitly verifies that the Android-host condition/return in `Platform/Android-Determine.cmake` occurs before the later unsupported-host fatal branch, and verifies the C/CXX explicit-compiler early returns.

## Material build executables also pinned

The TOCTOU scope was conservatively extended beyond Lane243's minimum request:

- CMake: `/data/data/com.termux/files/usr/bin/cmake`, SHA-256 `07c5f6bfdc48dd4f79085438ce4ab4b467313f31c9aadf5125fc3fd69ee0e682`, version 4.4.1.
- Ninja: `/data/data/com.termux/files/usr/bin/ninja`, SHA-256 `ad71fefa515777f6331530b12aedeb44acf3f9b9ce56af5ebaafa8fe799a1204`.
- ccache: `/data/data/com.termux/files/usr/bin/ccache`, SHA-256 `cef760b84c3143a70d15b4bc38edd52f85f8f01eec58db40eb80f14eb27a35ed`.

Configure explicitly sets the absolute `CMAKE_MAKE_PROGRAM` to pinned Ninja and the absolute C compiler launcher to pinned ccache. The post-configure graph gate verifies both identities are represented in generated state. The CXX audit launcher independently revalidates ccache and the exact CXX compiler hash immediately before every compiler execution.

## Preserved fail-closed gates

The v4 scripts preserve the reviewed Lane241 architecture:

- exact real `gd-team-heavy` label/PID/cmdline/fd9/ancestry/flock proof;
- externally reviewed commit + wrapper + launcher SHA approval;
- exact one-parent provenance atop Lane241 and unchanged native source relative to Lane241;
- exact six-file Lane220 divergence versus canonical, including the single Android runtime definition;
- exact canonical HEAD/status fingerprint;
- stock r29 source/toolchain/sysroot and Termux compatibility-link hashes;
- fresh build-directory requirement;
- >=4 GiB free-space preflight;
- host/target leak graph checks;
- critical candidate-TU compile audit;
- AArch64/artifact/runtime-dependency/canary checks;
- `--parallel 1` plus the separate global-heavy lock.

Both future configure and build invoke only the absolute pinned CMake path. There is no bare runtime `cmake` command.

## Static validation

- `bash -n` for wrapper and launcher — PASS.
- `git diff --check` — PASS before commit.
- Static order assertions — PASS: preflight identity check precedes first build-tree `mkdir`; the second identity check immediately precedes configure; the third immediately precedes build.
- Static material-tool assertions — PASS for CMake, Ninja and ccache absolute paths/hashes.
- Current read-only identities still match the embedded pins; current host reports Android/aarch64.
- Current CMake semantic source inspection confirms Android condition line 29, return line 30, and later unsupported-host fatal line 300; both language modules retain their explicit-compiler first-line return behavior.

Final v4 SHA-256 values:

- wrapper: `79b48ed0621d27ac429d340c9cf7e8eb1f2a97d6be235d07f907923e05128d98`
- launcher: `26e2cd1c44e358225a728da17fa237efe6efe44711acb513204c4d06fca8bc8b`

## Current resource/runtime status

This lane is intentionally sparse and was not expanded into a buildable source checkout. At final static validation `/data` free space was only slightly above the nominal 4 GiB gate and does not provide safe build headroom. No build is authorized from this lane itself.

The next step is independent static review of this exact commit. Even if accepted, the GTA diagnostic path still requires a separately reviewed observation-core instrumentation change before any serialized build/runtime attempt.
