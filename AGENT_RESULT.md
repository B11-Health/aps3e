# Lane193 — Lane190 build wrapper v2 correction

Date: 2026-09-12
Branch: `team/prod-spurs-canary-build-wrapper-v2`
Base exact commit: `5bcb30260fce516c23e77b5ba32a43c09dd5d606`
Scope: script + report only. Neither Lane193 script was executed. No CMake configure, compile, Ninja, tests, GTA, APK/NDK build, install, push, merge, workflow dispatch, cleanup, or deletion was performed.

## Final disposition

**READY_FOR_FRESH_INDEPENDENT_REVIEW**

Lane193 adds a fail-closed wrapper/launcher pair for a future single serialized compile/link-only `libe.so` build. It does not authorize execution, does not claim runtime correctness or playability, and leaves Lane190 history, Lane187 source, canonical source, and the contaminated retired build tree untouched.

## Coordinator correction — contaminated old build tree

The appended 2026-09-12 19:28 EDT correction is incorporated explicitly:

- retired contaminated evidence path: `$HOME/.cache/gd-prod-spurs-lane187-canary-build`;
- only permitted future fresh build tree: `$HOME/.cache/gd-prod-spurs-lane187-canary-build-v2`;
- wrapper pins `OLD_CONTAMINATED_BUILD`, pins `FRESH_BUILD_V2`, and assigns `BUILD` only from the v2 constant (`LANE193_BUILD_WRAPPER.sh:31-33`);
- wrapper accepts no positional build-directory override and fails unless the active path is exactly the pinned v2 path; it explicitly refuses equality with the contaminated old path (`411-414`);
- wrapper fails closed if the v2 path already exists or is symlinked and never auto-deletes it (`528-537`);
- initial read-only static inspection found the old path present as a directory and the v2 path absent. A later final read-only verification found both paths absent. No Lane193 command or script deleted, moved, cleaned, reused, restored, or recreated the old tree; its disappearance occurred outside the Lane193 operations documented here, so the original contaminated tree can no longer be asserted present at finalization;
- future build parallelism remains exactly `cmake --build "$BUILD" --target emu --parallel 1` (`502`).

## Concurrency/provenance note

While this correction was being applied, another local Lane193 process created unreviewed commit `739cf1402865baa761fb6782dc50572d7e4b4615` with parent `5bcb30260fce516c23e77b5ba32a43c09dd5d606`. Rather than stacking a partial correction commit, that local commit was amended after the corrected v2-path/static checks. The final commit therefore remains a single Lane193 commit directly on the exact required base and its parent diff contains exactly `AGENT_RESULT.md`, `LANE193_BUILD_WRAPPER.sh`, and `LANE193_OVERLAY_CXX_LAUNCHER.sh`.

## Exact script identities prepared for review

- `LANE193_BUILD_WRAPPER.sh`
  - SHA-256: `824e664a7959c3ede189c486894bffc8218a32d34e0767add42eae7f2d4622ff`
  - Git blob ID: `f9de9ce162922acf52284b499465d046eb222c0a`
  - mode: executable `0700`
- `LANE193_OVERLAY_CXX_LAUNCHER.sh`
  - SHA-256: `e6d4a1acd3ee62a1bbd95748c1ece48ec7bc8da25daa76cfd639128a9ccf1b70`
  - Git blob ID: `5dbaf29b427c5b17d5105e057071c99afe966b9b`
  - mode: executable `0700`

The final Lane193 commit SHA cannot be self-embedded in the same committed script bytes without a circular rewrite. The wrapper therefore requires the coordinator to supply the exact independently approved Lane193 commit plus both script SHA-256 values at execution time and proves that runtime files equal the Git blobs at that approved commit before configure and again before build/postflight.

## Mandatory pins retained

`LANE193_BUILD_WRAPPER.sh:7-35` pins the exact Lane193 worktree, exact Lane190 base, canonical source root, Lane187 worktree, Lane187 HEAD `cf5cb967e706fde89fd9fc76eed5f5b052e50a36`, Lane187 protected-TU SHA-256 values `c1c3731fd34823eebd88d87ab5bde00f38147e7e78d68bd93d898440161dd6f4` and `f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570`, canonical HEAD `7dc95e6baaac0712d5b3c28501778dd7934e579b`, canonical status fingerprint `36b6a6d7e79282cb43e415bc4e076873c2d4b974576e5168c2844e0ff569e4bf`, NDK revision `29.0.14206865`, NDK toolchain SHA-256 `dbad92d9dcfea0d32b7c5e5f82f5072d878ded5d46a5d3f1f581ea108ca7fe89`, the corrected v2 build path, and the `4194304 KiB` `/data` gate.

Canonical protected-TU pins are also retained:

- `cellSpurs.cpp`: `fe9fc920ad97d993b8223a3695fc91512928b58310aa39659d7151f53944347b`;
- `cellSpursSpu.cpp`: `95e855384ee80ebeadd6c35300f8f093bf4d8345f4cdacca14bad6d08080fcc9`.

The future recipe remains NDK r29 / `arm64-v8a` / `android-24` / platform level 24 / Release / `c++_shared` / Ninja, target `emu`, root output `$BUILD/libe.so`, and `--parallel 1` (`478-502`).

## Lane191 Blocker 1–13 closure map

| Lane191 blocker | Lane193 correction | Exact source lines |
|---|---|---|
| 1. Trace/run-dir contract mismatch | Creates one collision-resistant run directory keyed by approved wrapper SHA + UTC + PID, refuses preexistence/symlink, creates the trace inside it, exports `LANE193_TRACE_PATH`, and the launcher enforces the identical prefix/suffix/header contract. | wrapper `424-466`; launcher `24-28`, `58-69` |
| 2. No post-configure free-space gate | `snapshot_state` parses numeric `/data` free KiB and hard-fails below `4194304`; it runs immediately after successful configure and again immediately before build. | wrapper `265-271`, calls `550-551`, `559-560` |
| 3. No post-configure source/revision recheck | `snapshot_state` revalidates successful Lane187 status + exact HEAD + both candidate hashes, canonical HEAD/status fingerprint + protected-TU hashes, NDK revision/toolchain hash, and storage. It runs preflight, post-configure, pre-build, and postflight. | wrapper `218-292`, calls `525-526`, `550-551`, `559-560`, `622-623` |
| 4. No strict generated CMakeCache gate | Semantic `KEY[:TYPE]=VALUE` parser requires exactly one non-malformed semantic key and exact value; ABI/platform/STL/Release/Ninja/toolchain/launchers/source-change/try-compile/pthread/curl/iconv/charset/zlib pins are enumerated. | wrapper `294-352` |
| 5. No generated Ninja graph gate | Requires regular non-symlink `build.ninja`; rejects ambiguous `build emu:` mappings and accepts exactly one `build emu: phony libe.so`, recording line evidence. | wrapper `354-371` |
| 6. Trace schema not strict | Versioned header plus exactly six fields is fixed. Validator rejects wrong header, malformed/extra rows, bad UTC shape, empty compiler, unknown TU, wrong hash/path, and requires both protected TUs at least once. Launcher writes exact canonical/candidate identities. | wrapper `35`, `373-409`; launcher `24`, `170-187` |
| 7. Artifact uniqueness under-scoped | Recursive `find "$BUILD" -name libe.so -print0`, preserved `find` RC, exactly one result, exact root `$BUILD/libe.so`, regular non-symlink/nonzero file, and exact canonical path. | wrapper `576-595` |
| 8. Fragile `file(1)` regex | `file` is evidence only; `readelf -h` is structural authority requiring `Class: ELF64`, `Type: DYN`, and `Machine: AArch64`, plus nonzero byte checks. | wrapper `597-617` |
| 9. Self-provenance could drift | Requires external exact approved commit + both script SHA values, rejects symlinked scripts, requires exact worktree path, approved HEAD, clean status, Lane190 ancestry, runtime SHA match, and runtime Git blob equality to approved commit; rechecked before build/postflight. Launcher repeats provenance at protected-TU substitution time. | wrapper `159-216`, calls `421-422`, `562-563`, `625-626`; launcher `125-162` |
| 10. `git status` could fail open | Every cleanliness/status authority command is checked for command success before interpreting output; canonical NUL status hashing is under `pipefail`; no authority check uses `|| true`. | wrapper `108-120`, `173-216`, `222-246`; launcher `45-50`, `134-168` |
| 11. Stage/RC evidence not truthful | Explicit `STAGE` precedes phases; configure/build capture separate original RCs; EXIT finalizer preserves the original RC, records final stage/result/run, handles HUP/INT/TERM through EXIT, and exits with the original RC. | wrapper `54-94`, configure `539-548`, build `565-574`, success `628-640` |
| 12. Evidence overwrite/symlink/mutability hazards | `umask 077`; noclobber/non-symlink creation; unique `0700` run dir must not preexist; all evidence is inside it; failed evidence is retained; finalizer makes evidence files `0444` and run dir `0500`. | wrapper `3`, `59-82`, `144-157`, `424-466` |
| 13. Evidence bundle incomplete | Bundle includes preflight manifest, runtime identities, exact commands, pre/post source+NDK snapshots, configure/build logs+RCs, cache validation, Ninja graph evidence, full trace+summary, recursive-find evidence, `file`, `readelf`, artifact SHA/bytes, result and final stage/RC/result. | wrapper `436-460`, `468-523`, `539-640` |

## Additional fail-closed requirements

- Canonical and Lane187 source are read-only inputs. Neither script contains reset/stash/clean/remove operations against those trees.
- The contaminated old build path has no write/delete/reuse path in Lane193. It was observed present initially but absent at finalization; Lane193 does not recreate it because doing so would alter/fabricate evidence.
- The fresh v2 build path is immutable in the script and must not preexist (`31-33`, `411-414`, `528-537`).
- Launcher substitutes only the two exact canonical SPURS source arguments; direct Lane187 candidate paths and every unexpected path ending in either protected TU name are rejected (`93-123`).
- At substitution time the launcher verifies exact Lane193 provenance, successful Lane187 clean status/HEAD, candidate SHA, canonical protected-TU SHA, then substitutes and appends canonical `-I$ORIG` include context while preserving the original argument array (`125-190`).
- No network dependency is used by the Lane193 scripts.
- No Lane184 evidence/build tree is mutated or consumed at runtime.
- Wrapper does not acquire the heavy slot internally; external coordinator ownership remains mandatory.
- Evidence-directory creation is small metadata/text; the dedicated build output is separate.

## Static checks performed

Only permitted static/read-only checks were used:

- re-read the appended `COORDINATOR CORRECTION` and `STATIC REFERENCE NOTE` in the Lane193 task;
- re-read shared resource policy, Lane191 independent rejection, and Lane189 build-readiness recipe evidence;
- `bash -n LANE193_BUILD_WRAPPER.sh LANE193_OVERLAY_CXX_LAUNCHER.sh`: **PASS**;
- `git diff --check`: **PASS**;
- executable modes: both `0700`: **PASS**;
- forbidden runtime/install/cleanup/internal-heavy command scan: **PASS**;
- authority `|| true` scan: **PASS**;
- exact v2/old-path refusal/`--parallel 1` contract grep: **PASS**;
- read-only path inspection: old contaminated tree **present initially, absent at final verification**; v2 tree **absent throughout these checks**;
- script SHA-256 and Git blob identities recomputed as listed above.

A first broad static grep matched the literal tool-name `ninja` in the wrapper's required-tool list; that was a scan-pattern false positive, not command execution. The corrected forbidden-action scan excludes passive tool-name/configuration literals and passed.

No wrapper/launcher execution, CMake configure, compile, Ninja, test, GTA, APK/NDK build, install, push, merge, workflow dispatch, cleanup, or deletion occurred.

## Limitations and next gate

1. Lane193 is static wrapper/launcher design evidence only; it does not prove a future configure/build succeeds.
2. The retired contaminated build tree was observed disappearing during Lane193 authoring even though Lane193 performed no deletion/cleanup. Its final absence is an external-state anomaly to preserve in coordinator provenance; do not recreate it and do not treat the retired path as usable.
3. Fresh independent review must approve this exact final Lane193 commit and both script identities before any heavy action.
4. The reviewer/coordinator must supply that exact approved Lane193 commit and the two exact script SHA-256 values at execution time; arbitrary clean descendants are rejected.
5. If `$HOME/.cache/gd-prod-spurs-lane187-canary-build-v2` exists at execution time, the wrapper must fail closed. The retired non-v2 tree is never a fallback.
6. Any later successful build is compile/link evidence only, not GTA runtime correctness, Story Mode, gameplay, audio, frame pacing, or playability.

## Future exact coordinator invocation shape — not executed here

Only after a fresh independent review approves the final Lane193 commit `<APPROVED_LANE193_COMMIT>` may the coordinator supply one external heavy ownership interval and immutable environment contract:

```sh
LANE193_APPROVED_COMMIT=<APPROVED_LANE193_COMMIT> \
LANE193_APPROVED_WRAPPER_SHA256=824e664a7959c3ede189c486894bffc8218a32d34e0767add42eae7f2d4622ff \
LANE193_APPROVED_LAUNCHER_SHA256=e6d4a1acd3ee62a1bbd95748c1ece48ec7bc8da25daa76cfd639128a9ccf1b70 \
~/.local/bin/gd-team-heavy lane187-prod-spurs-canary-libe -- \
/data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane193-prod-spurs-canary-build-wrapper-v2/LANE193_BUILD_WRAPPER.sh
```

The future wrapper run itself independently proves the runtime scripts match those SHA-256 values and the Git blobs at `<APPROVED_LANE193_COMMIT>`. No such invocation was performed by Lane193.

**READY_FOR_FRESH_INDEPENDENT_REVIEW**
