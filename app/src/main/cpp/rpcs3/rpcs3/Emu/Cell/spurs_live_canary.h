#pragma once

#include "util/types.hpp"

class spu_thread;

namespace spurs_live_canary
{
	struct snapshot
	{
		u32 context = 0;
		u32 taskset = 0;
		u32 task = 0;
	};

	void arm(u32 context, u32 taskset, u32 task);
	bool active();
	bool read(snapshot& out);
	void observe_mfc(spu_thread* spu, u32 cmd, u32 eal, u32 lsa, u32 size, u32 tag);
}
