#pragma once

#include "util/types.hpp"

#include <array>
#include <string>

namespace postbikini_probe
{
	struct plane_snapshot
	{
		u32 ea = 0;
		u32 size = 0;
		u32 pitch = 0;
		u32 height = 0;
		u64 nonzero = 0;
		std::string sha256;
	};

	struct completed_snapshot
	{
		u64 txn = 0;
		u32 bink_lv2 = 0;
		u32 handle = 0;
		u32 slot = 0;
		std::array<plane_snapshot, 3> planes{};
	};

	void identify_bink_spu(u32 lv2_id, u64 taskset, u32 task, u32 elf_addr, u32 entry);
	bool read_completed(completed_snapshot& out);
	bool mark_rsx_source(u64 txn, u32 plane_index, u32 source_ea);
}
