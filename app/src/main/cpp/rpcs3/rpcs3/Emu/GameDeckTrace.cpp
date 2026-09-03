#include "stdafx.h"
#include "GameDeckTrace.h"

#if defined(__ANDROID__)
#include <algorithm>
#include <atomic>
#include <cerrno>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <mutex>
#include <sys/syscall.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#endif

namespace gamedeck_trace
{
#if defined(__ANDROID__)
	namespace
	{
		std::once_flag g_init_once;
		std::mutex g_write_mutex;
		std::atomic<std::uint64_t> g_seq{0};
		int g_fd = -1;
		char g_path[1024]{};

		std::uint64_t monotonic_ns() noexcept
		{
			timespec ts{};
			if (::clock_gettime(CLOCK_MONOTONIC, &ts) != 0)
			{
				return 0;
			}
			return static_cast<std::uint64_t>(ts.tv_sec) * 1000000000ull + static_cast<std::uint64_t>(ts.tv_nsec);
		}

		long current_tid() noexcept
		{
			return static_cast<long>(::syscall(SYS_gettid));
		}

		void raw_write(const char* data, std::size_t size) noexcept
		{
			if (g_fd < 0 || !data || !size)
			{
				return;
			}

			const char* ptr = data;
			std::size_t left = size;
			while (left)
			{
				const ssize_t n = ::write(g_fd, ptr, left);
				if (n > 0)
				{
					ptr += n;
					left -= static_cast<std::size_t>(n);
					continue;
				}
				if (n < 0 && errno == EINTR)
				{
					continue;
				}
				break;
			}
		}

		void init() noexcept
		{
			const char* qa_dir = std::getenv("GAMEDECK_PS3_QA_DIR");
			if (!qa_dir || !*qa_dir)
			{
				// QA package fallback. Production builds do not grant this package-scoped path.
				qa_dir = "/sdcard/Android/media/io.gamedeck.mobile.desktoppreview.qa/GameDeck-Console/qa";
			}

			const std::uint64_t start = monotonic_ns();
			const int pid = static_cast<int>(::getpid());
			const int len = std::snprintf(g_path, sizeof(g_path), "%s/clean-engine-trace-%d-%llu.tsv", qa_dir, pid,
				static_cast<unsigned long long>(start));
			if (len <= 0 || static_cast<std::size_t>(len) >= sizeof(g_path))
			{
				return;
			}

			g_fd = ::open(g_path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0660);
			if (g_fd < 0)
			{
				return;
			}

			char line[512]{};
			const int n = std::snprintf(line, sizeof(line),
				"seq=0\tmono_ns=%llu\tpid=%d\ttid=%ld\tevent=trace_start\tmutation=none\tformat=tsv-v1\n",
				static_cast<unsigned long long>(start), pid, current_tid());
			if (n > 0)
			{
				raw_write(line, static_cast<std::size_t>(n));
			}
		}
	}
#endif

	bool enabled() noexcept
	{
#if defined(__ANDROID__)
		std::call_once(g_init_once, init);
		return g_fd >= 0;
#else
		return false;
#endif
	}

	std::uint64_t now_ns() noexcept
	{
#if defined(__ANDROID__)
		return monotonic_ns();
#else
		return 0;
#endif
	}

	void emit(const char* event, const char* fmt, ...) noexcept
	{
#if defined(__ANDROID__)
		if (!event || !enabled())
		{
			return;
		}

		char details[1024]{};
		if (fmt && *fmt)
		{
			va_list args;
			va_start(args, fmt);
			std::vsnprintf(details, sizeof(details), fmt, args);
			va_end(args);
		}

		char line[1536]{};
		const std::uint64_t seq = g_seq.fetch_add(1, std::memory_order_relaxed) + 1;
		const int n = std::snprintf(line, sizeof(line),
			"seq=%llu\tmono_ns=%llu\tpid=%d\ttid=%ld\tevent=%s\tmutation=none%s%s\n",
			static_cast<unsigned long long>(seq),
			static_cast<unsigned long long>(monotonic_ns()),
			static_cast<int>(::getpid()), current_tid(), event,
			details[0] ? "\t" : "", details);
		if (n <= 0)
		{
			return;
		}

		const std::size_t size = std::min<std::size_t>(static_cast<std::size_t>(n), sizeof(line) - 1);
		std::lock_guard lock(g_write_mutex);
		raw_write(line, size);
#else
		(void)event;
		(void)fmt;
#endif
	}
}
