#include "stdafx.h"
#include "nv406e.h"
#include "nv47_sync.hpp"

#include "Emu/RSX/RSXThread.h"
#include "Emu/GameDeckTrace.h"

#include "context_accessors.define.h"

namespace rsx
{
	namespace nv406e
	{
		void set_reference(context* ctx, u32 /*reg*/, u32 arg)
		{
			RSX(ctx)->sync();

			// Write ref+get (get will be written again with the same value at command end)
			auto& dma = *vm::_ptr<RsxDmaControl>(RSX(ctx)->dma_address);
			dma.get.release(RSX(ctx)->fifo_ctrl->get_pos());
			dma.ref.store(arg);
		}

		void semaphore_acquire(context* ctx, u32 /*reg*/, u32 arg)
		{
			RSX(ctx)->sync_point_request.release(true);
			const u32 gd_offset = REGS(ctx)->semaphore_offset_406e();
			const u32 gd_ctxt = REGS(ctx)->semaphore_context_dma_406e();
			const u32 addr = get_address(gd_offset, gd_ctxt);

#if defined(__ANDROID__)
			if (addr == RSX(ctx)->label_addr + 0x480)
			{
				static thread_local u64 gd_label72_acquire_count = 0;
				const u64 gd_n = ++gd_label72_acquire_count;
				if (gd_n <= 32 || (gd_n & 0xffu) == 0)
				{
					gamedeck_trace::emit("label72_acquire", "count=%llu\targ=%u\tcurrent=%u\tget=0x%08x\tput=0x%08x", static_cast<unsigned long long>(gd_n), arg, vm::read32(addr), RSX(ctx)->ctrl ? +RSX(ctx)->ctrl->get : 0u, RSX(ctx)->ctrl ? +RSX(ctx)->ctrl->put : 0u);
				}
			}
#endif

			// Syncronization point, may be associated with memory changes without actually changing addresses
			RSX(ctx)->m_graphics_state |= rsx::pipeline_state::fragment_program_needs_rehash;

			const auto& sema = vm::_ref<RsxSemaphore>(addr);
			const auto& atomic_sema = vm::_ref<atomic_t<RsxSemaphore>>(addr);

			if (sema == arg)
			{
				// Flip semaphore doesnt need wake-up delay
				if (addr != RSX(ctx)->label_addr + 0x10)
				{
					RSX(ctx)->flush_fifo();
					RSX(ctx)->fifo_wake_delay(2);
				}

				return;
			}
			else
			{
				RSX(ctx)->flush_fifo();
			}

			u64 start = get_system_time();
			u64 last_check_val = start;

#if defined(__ANDROID__)
			gamedeck_trace::emit("nv406e_wait_begin", "addr=0x%08x\toffset=0x%08x\tctxt=0x%08x\texpected=%u\tobserved=%u\tget=0x%08x\tput=0x%08x",
				addr, gd_offset, gd_ctxt, arg, vm::read32(addr), RSX(ctx)->ctrl ? +RSX(ctx)->ctrl->get : 0u, RSX(ctx)->ctrl ? +RSX(ctx)->ctrl->put : 0u);
#endif

			while (sema != arg)
			{
				if (RSX(ctx)->test_stopped())
				{
					RSX(ctx)->state += cpu_flag::again;
					return;
				}

				if (const auto tdr = static_cast<u64>(g_cfg.video.driver_recovery_timeout))
				{
					const u64 current = get_system_time();

					if (current - last_check_val > 20'000)
					{
						// Suspicious amnount of time has passed
						// External pause such as debuggers' pause or operating system sleep may have taken place
						// Ignore it
						start += current - last_check_val;
					}

					last_check_val = current;

					if ((current - start) > tdr)
					{
						// If longer than driver timeout force exit
						rsx_log.error("nv406e::semaphore_acquire has timed out. semaphore_address=0x%X", addr);
						break;
					}
				}

				if (RSX(ctx)->external_interrupt_lock ||
					(RSX(ctx)->state & (cpu_flag::dbg_global_pause + cpu_flag::exit)) == cpu_flag::dbg_global_pause)
				{
					RSX(ctx)->cpu_wait({});
					continue;
				}

				// Current upstream RPCS3 semantics: service backend work while waiting,
				// then wait on the actual semaphore cacheline. On ARM64 this uses WFE
				// instead of continuously yielding the RSX host thread.
				RSX(ctx)->on_semaphore_acquire_wait();
				utils::spin_on_cacheline_once(atomic_sema, sema, 100);
			}

#if defined(__ANDROID__)
			gamedeck_trace::emit("nv406e_wait_end", "addr=0x%08x\texpected=%u\tobserved=%u\tduration_us=%llu\tget=0x%08x\tput=0x%08x",
				addr, arg, vm::read32(addr), static_cast<unsigned long long>(get_system_time() - start), RSX(ctx)->ctrl ? +RSX(ctx)->ctrl->get : 0u, RSX(ctx)->ctrl ? +RSX(ctx)->ctrl->put : 0u);
#endif
			RSX(ctx)->fifo_wake_delay();
			RSX(ctx)->performance_counters.idle_time += (get_system_time() - start);
		}

		void semaphore_release(context* ctx, u32 reg, u32 arg)
		{
			const u32 offset = REGS(ctx)->semaphore_offset_406e();

			if (offset % 4)
			{
				rsx_log.warning("NV406E semaphore release is using unaligned semaphore, ignoring. (offset=0x%x)", offset);
				return;
			}

			const u32 ctxt = REGS(ctx)->semaphore_context_dma_406e();

			// By avoiding doing this on flip's semaphore release
			// We allow last gcm's registers reset to occur in case of a crash
			if (const bool is_flip_sema = (offset == 0x10 && ctxt == CELL_GCM_CONTEXT_DMA_SEMAPHORE_R);
				!is_flip_sema)
			{
				RSX(ctx)->sync_point_request.release(true);
			}

			const u32 addr = get_address(offset, ctxt);

#if defined(__ANDROID__)
			if (addr == RSX(ctx)->label_addr + 0x480)
			{
				static thread_local u64 gd_label72_release_count = 0;
				const u64 gd_n = ++gd_label72_release_count;
				if (gd_n <= 32 || (gd_n & 0xffu) == 0)
				{
					gamedeck_trace::emit("label72_release", "count=%llu\targ=%u\tcurrent=%u\toffset=0x%x\tctxt=0x%x\tget=0x%08x\tput=0x%08x", static_cast<unsigned long long>(gd_n), arg, vm::read32(addr), offset, ctxt, RSX(ctx)->ctrl ? +RSX(ctx)->ctrl->get : 0u, RSX(ctx)->ctrl ? +RSX(ctx)->ctrl->put : 0u);
				}
			}
#endif

			// TODO: Check if possible to write on reservations
			if (RSX(ctx)->label_addr >> 28 != addr >> 28)
			{
				rsx_log.error("NV406E semaphore unexpected address. Please report to the developers. (offset=0x%x, addr=0x%x)", offset, addr);
				RSX(ctx)->recover_fifo();
				return;
			}

			if (addr == RSX(ctx)->device_addr + 0x30 && !arg)
			{
				// HW flip synchronization related, 1 is not written without display queue command (TODO: make it behave as real hw)
				arg = 1;
			}

			util::write_gcm_label<false, true>(ctx, reg, addr, arg);
		}
	}
}
