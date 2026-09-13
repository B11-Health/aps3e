# Lane207 result

Starting HEAD: 778bfb54dc3d883959e483aa52637a53cd6e21ed
Lane205 ancestor: 9053cf624e2ac0a6e56ff926cb632b48ff79bb4b (verified)

Implemented only the authorized fresh-v7 successor changes:
- wrapper and launcher WORKTREE now point to lane207-v7-fresh-build-successor;
- consumed build-v6 is now PRIOR_FRESH_BUILD_V6;
- new exact build target is build-v7;
- BUILD points to v7;
- path contract says v7 and adds unique rc 171 refusal for consumed v6.

Preserved checks verified:
- Lane205 classifier still has no blanket Vulkan_ arm;
- generic LIBRARY/LIBRARIES/LIBDIR/LDFLAGS/INCLUDE/INCLUDEDIR/INCLUDE_DIR/INCLUDE_DIRS target-role matcher remains;
- LIBUSB_ and pkgcfg_ guards remain;
- Vulkan_LIBRARY remains pinned to the Android NDK sysroot;
- CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER remains;
- MIN_KIB=4194304 remains;
- build remains --parallel 1;
- existing/symlinked BUILD path refusal remains.

Static checks: bash -n wrapper PASS; bash -n launcher PASS; git diff --check PASS.
The executable diff contains only the authorized worktree-identity and v6-to-v7 lifecycle hunks.

Consumed v6 CMakeCache was inspected read-only: SHA256 b8b6ac65e335c8e2c28aef9e39b0011088fc235ece6234f2374453abf6c2e710, 119479 bytes. v7 remained absent after static work.

Current script hashes:
- wrapper fd9cd642759c8cbdf4091107fc74413341c972ea50b88b479bfbcb787875e818
- launcher 9ab631b81f3d0d8496f5ad86b6079e15cd6147f1c9bbc91c5a9c286c3f484a67

Observed free space during validation: 4712260 KiB, above the 4194304 KiB heavy-start gate. Recheck before any heavy run.

No configure, compile, Ninja, Gradle, APK/NDK build, GTA run, install, merge, cleanup, deletion, or v6 mutation was performed. Lane207 requires independent review before any v7 build.
