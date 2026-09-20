#include "stdafx.h"
#include "MM.h"
#include <Emu/RSX/Common/simple_array.hpp>
#include <Emu/RSX/RSXOffload.h>
#include <Emu/RSX/rsx_utils.h>

#include <Emu/Memory/vm.h>
#include <Emu/IdManager.h>
#include <Emu/system_config.h>
#include <Utilities/address_range.h>
#include <Utilities/mutex.h>

namespace rsx
{
	rsx::simple_array<MM_block> g_deferred_mprotect_queue;
	shared_mutex g_mprotect_queue_lock;

	void mm_flush_mprotect_queue_internal(u32 count)
	{
		AUDIT(count <= g_deferred_mprotect_queue.size());

		for (u32 i = 0; i < count; ++i)
		{
			const auto& block = g_deferred_mprotect_queue[i];
			utils::memory_protect(reinterpret_cast<void*>(block.range.start), block.range.length(), block.prot);
		}

		const u32 remaining = g_deferred_mprotect_queue.size() - count;
		if (!remaining)
		{
			g_deferred_mprotect_queue.clear();
			return;
		}

		// Preserve the relative ordering of deferred requests newer than the flushed prefix.
		for (u32 i = 0; i < remaining; ++i)
		{
			g_deferred_mprotect_queue[i] = g_deferred_mprotect_queue[i + count];
		}
		g_deferred_mprotect_queue.resize(remaining);
	}

	void mm_defer_mprotect_internal(u64 start, u64 length, utils::protection prot)
	{
		// We could stack and merge requests here, but that is more trouble than it is truly worth.
		// A fresh call to memory_protect only takes a few nanoseconds of setup overhead, it is not worth the risk of hanging because of conflicts.
		g_deferred_mprotect_queue.push_back({ utils::address_range64::start_length(start, length), prot, rsx::get_shared_tag() });
	}

	void mm_protect(void* ptr, u64 length, utils::protection prot)
	{
		if (g_cfg.video.disable_async_host_memory_manager)
		{
			utils::memory_protect(ptr, length, prot);
			return;
		}

		// Naive merge. Eventually it makes more sense to do conflict resolution, but it's not as important.
		const auto start = reinterpret_cast<u64>(ptr);
		const auto range = utils::address_range64::start_length(start, length);

		std::lock_guard lock(g_mprotect_queue_lock);

		if (prot == utils::protection::rw || prot == utils::protection::wx)
		{
			// Basically an unlock op. Flush if any overlap is detected
			for (const auto& block : g_deferred_mprotect_queue)
			{
				if (block.overlaps(range))
				{
					mm_flush_mprotect_queue_internal(g_deferred_mprotect_queue.size());
					break;
				}
			}

			utils::memory_protect(ptr, length, prot);
			return;
		}

		// No, Ro, etc.
		mm_defer_mprotect_internal(start, length, prot);
	}

	void mm_flush()
	{
		std::lock_guard lock(g_mprotect_queue_lock);
		mm_flush_mprotect_queue_internal(g_deferred_mprotect_queue.size());
	}

	void mm_flush(u32 vm_address)
	{
		std::lock_guard lock(g_mprotect_queue_lock);
		if (g_deferred_mprotect_queue.empty())
		{
			return;
		}

		const auto addr = reinterpret_cast<u64>(vm::base(vm_address));
		for (const auto& block : g_deferred_mprotect_queue)
		{
			if (block.overlaps(addr))
			{
				mm_flush_mprotect_queue_internal(g_deferred_mprotect_queue.size());
				return;
			}
		}
	}

	void mm_flush(const rsx::simple_array<utils::address_range64>& ranges)
	{
		std::lock_guard lock(g_mprotect_queue_lock);
		if (g_deferred_mprotect_queue.empty())
		{
			return;
		}

		for (const auto& block : g_deferred_mprotect_queue)
		{
			if (ranges.any(FN(block.overlaps(x))))
			{
				mm_flush_mprotect_queue_internal(g_deferred_mprotect_queue.size());
				return;
			}
		}
	}

	void mm_flush_lazy()
	{
		if (!g_cfg.video.multithreaded_rsx)
		{
			mm_flush();
			return;
		}

		std::lock_guard lock(g_mprotect_queue_lock);
		if (g_deferred_mprotect_queue.empty())
		{
			return;
		}

		auto& rsxdma = g_fxo->get<rsx::dma_manager>();
		rsxdma.backend_ctrl(mm_backend_ctrl::cmd_mm_flush, nullptr);
	}

	void mm_flush_partial(u64 last_tag)
	{
		std::lock_guard lock(g_mprotect_queue_lock);

		u32 count = 0;
		for (const auto& block : g_deferred_mprotect_queue)
		{
			if (block.sync_tag > last_tag)
			{
				break;
			}
			++count;
		}

		if (count)
		{
			mm_flush_mprotect_queue_internal(count);
		}
	}
}
