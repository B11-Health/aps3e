# Lane190 — Immutable Lane187 Android libe build wrapper

Date: 2026-09-12
Branch: `team/prod-spurs-canary-build-wrapper`
Base: exact Lane187 canary commit `cf5cb967e706fde89fd9fc76eed5f5b052e50a36`
Scope: script + report only. No configure, compile, Ninja, test, GTA, APK/NDK build, install, push, merge, workflow dispatch, cleanup, or deletion was performed.

## Final disposition

**WRAPPER_READY_FOR_INDEPENDENT_REVIEW**

This lane creates a fail-closed wrapper for a later single guarded heavyweight configure+build of the Lane187-instrumented Android ARM64 `libe.so`. This report does not approve execution of that wrapper and does not claim runtime correctness or playability.

## Independent pins verified

- Lane187 HEAD: `cf5cb967e706fde89fd9fc76eed5f5b052e50a36`; worktree clean.
- Lane187 `cellSpurs.cpp`: `c1c3731fd34823eebd88d87ab5bde00f38147e7e78d68bd93d898440161dd6f4`.
- Lane187 `cellSpursSpu.cpp`: `f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570`.
- Canonical repo HEAD: `7dc95e6baaac0712d5b3c28501778dd7934e579b`.
- Canonical full-status SHA-256 (`git status --porcelain=v1 -z | sha256sum`): `36b6a6d7e79282cb43e415bc4e076873c2d4b974576e5168c2844e0ff569e4bf`.
- NDK revision: `29.0.14206865` at `$HOME/android-sdk/ndk-r29-local`.
- Current `/data` static preflight during lane work exceeded the required 4 GiB gate; the wrapper rechecks `>=4194304 KiB` immediately before any configure/build.

## Lane184 authority used

Read-only Lane184 evidence shows the Android graph was configured from canonical `app/src/main/cpp` with Ninja, Release, the r29 Android CMake toolchain, `arm64-v8a`, API 24, `c++_shared`, C++ compiler launcher overlay, C launcher `ccache`, and the local iconv/charset/zlib pins. Lane184 `build.ninja`/command evidence shows target `emu` links root-level `libe.so` as an ELF64 AArch64 shared object.

The wrapper therefore derives the later heavy command as:

`cmake -S <canonical app/src/main/cpp> -B ~/.cache/gd-prod-spurs-lane187-canary-build -G Ninja` with the exact Lane184 Android flags encoded in `LANE190_BUILD_WRAPPER.sh`, followed in the same wrapper invocation by:

`cmake --build ~/.cache/gd-prod-spurs-lane187-canary-build --target emu --parallel 1`

The coordinator, not this wrapper, must own the global heavy slot externally, e.g. `gd-team-heavy lane187-prod-spurs-canary-libe -- <reviewed wrapper>` only after separate immutable approval.

## Overlay launcher behavior

`LANE190_OVERLAY_CXX_LAUNCHER.sh` is a fresh Lane187-pinned adaptation. It:

- requires exact Lane187 HEAD and clean status;
- substitutes only compiler source arguments exactly equal to canonical `cellSpurs.cpp` or `cellSpursSpu.cpp`;
- verifies the corresponding Lane187 instrumented SHA before substitution;
- preserves canonical include context with `-I<canonical Modules dir>` when substitution occurs;
- invokes Termux `ccache` plus the actual compiler passed by CMake;
- appends a Lane187-specific trace with UTC timestamp, TU identity, candidate SHA and compiler;
- rejects multiple target substitutions in one compiler invocation and never substitutes any other path.

Current launcher SHA-256: `9a304c6ff4299a5ee813f0a679dc4a77fb212f68bc4590590c582464c0ed8c19`.

## Build-wrapper fail-closed guards

`LANE190_BUILD_WRAPPER.sh` uses `set -euo pipefail` and records a final RC through an EXIT trap without deleting source/evidence. Before configure it requires:

1. required tools (`git`, hashes, CMake/Ninja, ccache, ELF inspection tools, etc.);
2. exact Lane187 HEAD, clean status and both pinned source hashes;
3. exact canonical HEAD plus exact existing canonical status fingerprint, without reset/stash/apply/overwrite;
4. exact NDK revision;
5. `/data` free space `>=4194304 KiB`;
6. a dedicated new build tree that must not already exist;
7. the reviewed launcher to be executable.

It records a preflight manifest containing timestamps, runtime wrapper/launcher hashes, source/repo pins, NDK/ABI/API/build type/STL, free space and shell-escaped exact configure/build commands.

After configure/build it requires:

- exactly one root-level `$BUILD/libe.so` and nonzero size;
- `file` evidence matching ELF64 ARM aarch64 shared object;
- `readelf` machine AArch64 and ELF type DYN;
- overlay trace unique identities exactly equal to the two intended Lane187 TUs, with each present at least once;
- Lane187 HEAD/clean/source hashes unchanged;
- canonical HEAD/status fingerprint unchanged;
- final artifact SHA-256, byte count and post-build free-space evidence.

It does not install/copy to canonical `jniLibs`, touch QA packaging, run GTA, use network, or depend on GitHub Actions. Build success is compile/link evidence only.

Current build-wrapper SHA-256: `a6925f5392286d692f05c5ae6bbb27db831763c3571c867b12a3c938ce1d0517`.

## Expected durable evidence from a future reviewed run

- build tree: `~/.cache/gd-prod-spurs-lane187-canary-build`
- trace: `~/.cache/gd-lane187-canary-overlay-trace.tsv`
- build log: `~/.cache/gd-lane187-canary-libe-build.log`
- manifest: `~/.cache/gd-lane187-canary-libe-manifest.txt`
- result: `~/.cache/gd-lane187-canary-libe-result.txt`
- RC: `~/.cache/gd-lane187-canary-libe.rc`
- artifact: `~/.cache/gd-prod-spurs-lane187-canary-build/libe.so`

## Static validation performed

Allowed non-heavy checks only: `bash -n` on both scripts, `git diff --check`, read-only Git HEAD/status verification, SHA-256 verification, NDK revision read, and `/data` free-space read. Neither script was executed.

## Limitations / next gate

This lane is self-authored wrapper evidence. It requires an independent source/script review before the coordinator may create an immutable approved execution script or consume the global heavy slot. After a successful build, Lane183 still requires the separate instrumented Bink runtime canary and independent evidence review before any production install/merge conclusion.
