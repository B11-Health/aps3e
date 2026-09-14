# Lane220 — Bink PUTLLC diagnostic canary

## Result
PASS — source-only, non-semantic diagnostic instrumentation is ready for independent review.

## Base
- Base commit: `5c974d060625c6e85b2fbc39d1e0bb15110e625d` (Lane212 non-perturbing live MFC canary).
- Installed/runtime lineage remains rooted in published Android runtime macro commit `2e217f4618c834ee9d851d1623b810a717c50c9d`.

## Why this lane exists
The authentic post-bikini black-screen run (`20260913-140023-Grand-Theft-Auto-V`) shows Bink SPU `0x03000100` actively spending CPU in LLVM MFC execution, especially `spu_thread::process_mfc_cmd()` and `spu_thread::do_putllc()`. The main PPU simultaneously blocks in `cellSpursQueuePopBody -> sys_event_queue_receive` because the expected SPURS Queue entry never arrives. Existing Lane212 observes ordinary DMA GET/PUT around the Bink/SPURS context but not PUTLLC.

## Change
Only `app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPUThread.cpp` is changed.

Inside `spu_thread::do_putllc()`:
- the existing immediately-invoked result lambda is stored in `putllc_success`;
- the original lambda body is unchanged;
- the original success/failure downstream bodies are unchanged;
- logging is limited to `lv2_id == 0x03000100` (the Bink SPU proven by 64-byte LS/image match);
- counters are `thread_local` and diagnostic only;
- log first 16 attempts, then 1/8192 attempts;
- fields: result, cumulative success/failure, EAL/aligned EA, LSA, tag, cmd, pre-raddr, pre-rtime, post-raddr, guest PC, pre-PC, SPURS address;
- no guest memory writes, no reservation changes, no altered return values, no retry/notification behavior changes, no hashes or memory copies in the canary path.

## Static proof
- `git diff --check`: PASS.
- Original PUTLLC result-lambda body vs Lane220 named-lambda body:
  - length: 2451 bytes / 2451 bytes
  - SHA256 before: `9dabb39ab9ef1f0d65ceecd171f48318c269da4943041ae2d640eb425bbead4e`
  - SHA256 after:  `9dabb39ab9ef1f0d65ceecd171f48318c269da4943041ae2d640eb425bbead4e`
  - `BODY_IDENTICAL=True`.
- Original downstream success/failure body vs Lane220 after condition normalization:
  - `DOWNSTREAM_IDENTICAL_AFTER_CONDITION_NORMALIZATION=True`.

## Important negative findings that constrain interpretation
- LLVM `MFC_WrTagUpdate` already has correct tag-status update semantics and matches current official RPCS3; do not patch TagStat/TagUpdate.
- `spu_thread::do_putllc()` and `spu_thread::process_mfc_cmd()` match official RPCS3 source (except whitespace in one comment); this lane is diagnostic only, not a proposed functional fix.
- Lane216 was foreground-contaminated by Chrome and must not be used as proof of a global SPU freeze.

## Runtime acceptance for this canary
After independent review and a cloud-built diagnostic core, capture `BINK_PUTLLC_CANARY` during one authentic post-bikini run. The goal is to identify the repeated EA/cache line and success/failure ratio; the canary itself is not a playability fix and must not be treated as success.
