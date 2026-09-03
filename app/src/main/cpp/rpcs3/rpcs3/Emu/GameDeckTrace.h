#pragma once

#include <cstdint>

namespace gamedeck_trace
{
	// Observation-only Android QA trace. On non-Android builds these are no-ops.
	bool enabled() noexcept;
	std::uint64_t now_ns() noexcept;
	void emit(const char* event, const char* fmt = nullptr, ...) noexcept;
}
