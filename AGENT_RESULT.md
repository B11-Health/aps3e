# Lane212 — Non-perturbing live SPURS/Bink MFC canary

## Scope
Debugger/instrumentation correction only. No build, install, GTA run, asset/config mutation, fence spoof, readiness spoof, fake frame, or guest-visible behavior change was performed.

## Runtime evidence motivating this lane
The 2026-09-13 13:19 debugger run (`~/gamedeck-debugger-runs/20260913-131927-Grand-Theft-Auto-V`) captured the reported bikini -> black failure.

- Visual luma stayed about 111 through capture t=174.415 s, then fell to 1.775 at t=179.326 s and remained about 1.799 through the black-static trigger.
- At first black, SurfaceFlinger was still measuring about 30.19 fps; this is not an app/process crash or immediate Android compositor disappearance.
- Trigger snapshot: SPU[0x0000100]=90.3% CPU; SPU[0x1000100], SPU[0x2000100], SPU[0x3000100]=83.8% each; `rsx::thread`=67.7%.
- simpleperf resolves RSX activity in `rsx::FIFO::FIFO_control::read`; SPU-side samples include `spu_thread::set_ch_value`, `sys_event_flag_set`, and `spu_thread::do_dma_transfer`.
- Native observer at the black state shows main PPU 0x01000000 blocked in the observed semaphore wait at CIA 0x01433ce0, producer PPU 0x0100000c repeatedly at CIA 0x00b6d324, observed RSX label72=0 while target=0x61010054, and observed exact GCM control `put=0 get=0 ref=0`.
- The installed core SHA256 is `1968258bc30ff4ab3dd996494f0047230c393a62c3fb354bee14c69c3ae35286`; it contains the older `SPURS_CANARY phase=CREATE` string but not `SPURS_CANARY_LIVE`, so it cannot answer whether the Bink SPURS 0x1400 context is actually saved/restored correctly at the transition.

## Lane210 review finding
Lane210 commit `9201bb6abbd0932fd28de2c00f9f75bfaa63a26a` added the required live context-DMA observation, but it also made `spurs_live_canary::active()` force `optimization_compatible=0` in `spu_thread::do_list_transfer`. Because the canary stays armed after the matching task is created, that changes normal list-DMA execution globally during the relevant period and can perturb timing/performance.

## Lane212 correction
`SPUThread.cpp` now:

1. Restores the original optimization eligibility gate: only existing trace/accurate-DMA/MFC-debug modes disable the list-DMA optimization.
2. Observes the six-element optimized GET path directly, using the same aligned LS stride and effective EA-derived LS offset as the fast copy path.
3. Observes the individual optimized GET path before its inline copy.
4. Observes the individual optimized PUT path before its inline copy.
5. Leaves the existing `do_dma_transfer` observation intact for non-inline transfers.

The observer remains read-only: it records metadata and hashes source bytes only when a transfer overlaps the armed 0x1400 context. It does not change DMA data, labels, fences, events, readiness, pixels, or guest memory.

## Static validation
- `git diff --check`: PASS.
- Verified `spurs_live_canary::active()` no longer participates in the `optimization_compatible = 0` gate.
- Verified observation coverage exists in ordinary `do_dma_transfer`, optimized six-element GET, optimized individual GET, and optimized individual PUT paths.
- No compile/build was run because the shared Android host was under high memory/swap pressure after the diagnostic run; per `TEAM_RESOURCE_POLICY.md`, heavyweight work was not started under that state.

## Diagnostic disposition
The current evidence localizes the failure to a live guest graphics/synchronization transition: execution continues, RSX/SPU threads are busy, but the guest command/fence chain is not progressing to visible Rockstar/loading content. The next discriminating runtime datum is the exact sequence and hashes of GET/PUT operations overlapping the Bink SPURS 0x1400 task context around the transition, captured with this non-perturbing canary.
