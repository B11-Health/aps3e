#include "Emu/Audio/Cubeb/CubebBackend.h"

#include <algorithm>
#include <cstdarg>
#include <cmath>
#include "util/logs.hpp"
#include "Emu/Audio/audio_device_enumerator.h"
#include "Emu/GameDeckTrace.h"
#include <atomic>

#ifdef _WIN32
#include <Windows.h>
#include <system_error>
#endif

LOG_CHANNEL(Cubeb);

CubebBackend::CubebBackend()
	: AudioBackend()
{
#ifdef _WIN32
	// Cubeb requires COM to be initialized on the thread calling cubeb_init on Windows
	if (HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED); SUCCEEDED(hr))
	{
		m_com_init_success = true;
	}
#endif

	cubeb *ctx{};
#ifdef __ANDROID__
    if (int err = cubeb_init(&ctx, "RPCS3", "aaudio"))
#else
        if (int err = cubeb_init(&ctx, "RPCS3", nullptr))
#endif
	{
		Cubeb.error("cubeb_init() failed: %i", err);
		return;
	}

	if (int err = cubeb_register_device_collection_changed(ctx, CUBEB_DEVICE_TYPE_OUTPUT, device_collection_changed_cb, this))
	{
		Cubeb.error("cubeb_register_device_collection_changed() failed: %i", err);
	}
	else
	{
		m_dev_collection_cb_enabled = true;
	}

	cubeb_set_log_callback(CUBEB_LOG_NORMAL, log_cb);

	Cubeb.notice("Using backend %s", cubeb_get_backend_id(ctx));

	std::lock_guard cb_lock{m_state_cb_mutex};
	m_ctx = ctx;
}

CubebBackend::~CubebBackend()
{
	Close();

	if (m_dev_collection_cb_enabled)
	{
		if (int err = cubeb_register_device_collection_changed(m_ctx, CUBEB_DEVICE_TYPE_OUTPUT, nullptr, nullptr))
		{
			Cubeb.error("cubeb_register_device_collection_changed() failed: %i", err);
		}
	}

	if (m_ctx)
	{
		cubeb_destroy(m_ctx);
	}

#ifdef _WIN32
	if (m_com_init_success)
	{
		CoUninitialize();
	}
#endif
}

bool CubebBackend::Initialized()
{
	return m_ctx != nullptr;
}

bool CubebBackend::Operational()
{
	return m_stream != nullptr && !m_reset_req.observe();
}

bool CubebBackend::DefaultDeviceChanged()
{
	if (m_default_device.empty() || m_reset_req.observe())
	{
		return false;
	}

	device_handle device = GetDevice();
	if (!device.handle)
	{
		Cubeb.error("Selected device not found. Trying alternative approach...");
		device = GetDefaultDeviceAlt(m_sampling_rate, m_sample_size, m_channels);
	}

	return !device.handle || device.id != m_default_device;
}

bool CubebBackend::Open(std::string_view dev_id, AudioFreq freq, AudioSampleSize sample_size, AudioChannelCnt ch_cnt, audio_channel_layout layout)
{
	if (!Initialized())
	{
		Cubeb.error("Open() called uninitialized");
		return false;
	}

	Close();
	std::lock_guard lock{m_cb_mutex};

	const bool use_default_device = dev_id.empty() || dev_id == audio_device_enumerator::DEFAULT_DEV_ID;

	if (use_default_device) Cubeb.notice("Trying to open default device");
	else Cubeb.notice("Trying to open device with dev_id='%s'", dev_id);

	device_handle device = GetDevice(use_default_device ? "" : dev_id);

	if (!device.handle)
	{
        if (use_default_device)
        {
            device = GetDefaultDeviceAlt(freq, sample_size, static_cast<u32>(ch_cnt));

            if (!device.handle)
            {
                Cubeb.error("Cannot detect default device. Channel count detection unavailable.");
            }
        }
        else
        {
            Cubeb.error("Device with id=%s not found", dev_id);
            return false;
        }
	}

	if (device.ch_cnt == 0)
	{
		Cubeb.error("Device reported invalid channel count, using stereo instead");
		device.ch_cnt = 2;
	}

	Cubeb.notice("Channel count is %d", device.ch_cnt);

	if (use_default_device)
	{
		std::lock_guard lock{m_state_cb_mutex};
		m_default_device = device.id;
	}

	m_sampling_rate = freq;
	m_sample_size = sample_size;

	setup_channel_layout(static_cast<u32>(ch_cnt), device.ch_cnt, layout, Cubeb);

	full_sample_size = get_channels() * get_sample_size();

	cubeb_stream_params stream_param{};
	stream_param.format = get_convert_to_s16() ? CUBEB_SAMPLE_S16NE : CUBEB_SAMPLE_FLOAT32NE;
	stream_param.rate = get_sampling_rate();
	stream_param.channels = get_channels();
	stream_param.layout = [&]()
	{
		switch (m_layout)
		{
		case audio_channel_layout::automatic:        break;
		case audio_channel_layout::mono:             return CUBEB_LAYOUT_MONO;
		case audio_channel_layout::stereo:           return CUBEB_LAYOUT_STEREO;
		case audio_channel_layout::stereo_lfe:       return CUBEB_LAYOUT_STEREO_LFE;
		case audio_channel_layout::quadraphonic:     return CUBEB_LAYOUT_QUAD;
		case audio_channel_layout::quadraphonic_lfe: return CUBEB_LAYOUT_QUAD_LFE;
		case audio_channel_layout::surround_5_1:     return CUBEB_LAYOUT_3F2_LFE;
		case audio_channel_layout::surround_7_1:     return CUBEB_LAYOUT_3F4_LFE;
		}

		fmt::throw_exception("Invalid audio layout %d", static_cast<u32>(m_layout));
	}();
	stream_param.prefs = m_dev_collection_cb_enabled && device.handle ? CUBEB_STREAM_PREF_DISABLE_DEVICE_SWITCHING : CUBEB_STREAM_PREF_NONE;

	u32 min_latency{};
	if (int err = cubeb_get_min_latency(m_ctx, &stream_param, &min_latency))
	{
		Cubeb.error("cubeb_get_min_latency() failed: %i", err);
		min_latency = 0;
	}

	const u32 stream_latency = std::max(static_cast<u32>(AUDIO_MIN_LATENCY * get_sampling_rate()), min_latency);

	if (int err = cubeb_stream_init(m_ctx, &m_stream, "Main stream", nullptr, nullptr, device.handle, &stream_param, stream_latency, data_cb, state_cb, this))
	{
		Cubeb.error("cubeb_stream_init() failed: %i", err);
		m_stream = nullptr;
		return false;
	}

	if (int err = cubeb_stream_start(m_stream))
	{
		Cubeb.error("cubeb_stream_start() failed: %i", err);
		Close();
		return false;
	}

#ifdef __ANDROID__
	// AAudio begins issuing callbacks as soon as cubeb_stream_start() succeeds.
	// Keep the software playback gate in sync with the already-started native stream;
	// Pause() still clears m_playing and Play() remains idempotent.
	m_playing = true;
#endif

	if (int err = cubeb_stream_set_volume(m_stream, 1.0))
	{
		Cubeb.error("cubeb_stream_set_volume() failed: %i", err);
	}

	return true;
}

void CubebBackend::Close()
{
	if (m_stream != nullptr)
	{
		if (int err = cubeb_stream_stop(m_stream))
		{
			Cubeb.error("cubeb_stream_stop() failed: %i", err);
		}

		cubeb_stream_destroy(m_stream);
	}

	{
		std::lock_guard lock{m_cb_mutex};
		m_stream = nullptr;
		m_playing = false;
		m_last_sample.fill(0);
	}

	std::lock_guard lock{m_state_cb_mutex};
	m_default_device.clear();
}

void CubebBackend::Play()
{
	if (m_stream == nullptr)
	{
		Cubeb.error("Play() called uninitialized");
		return;
	}

	if (m_playing) return;

	std::lock_guard lock(m_cb_mutex);
	m_playing = true;
}

void CubebBackend::Pause()
{
	if (m_stream == nullptr)
	{
		Cubeb.error("Pause() called uninitialized");
		return;
	}

	if (!m_playing) return;

	std::lock_guard lock(m_cb_mutex);
	m_playing = false;
	m_last_sample.fill(0);
}

f64 CubebBackend::GetCallbackFrameLen()
{
	if (m_stream == nullptr)
	{
		Cubeb.error("GetCallbackFrameLen() called uninitialized");
		return AUDIO_MIN_LATENCY;
	}

	u32 stream_latency{};
	if (int err = cubeb_stream_get_latency(m_stream, &stream_latency))
	{
		Cubeb.error("cubeb_stream_get_latency() failed: %i", err);
		stream_latency = 0;
	}

	return std::max<f64>(AUDIO_MIN_LATENCY, static_cast<f64>(stream_latency) / get_sampling_rate());
}

CubebBackend::device_handle CubebBackend::GetDevice(std::string_view dev_id)
{
	const bool default_dev = dev_id.empty();

	if (default_dev) Cubeb.notice("Searching for default device");
	else Cubeb.notice("Searching for device with dev_id='%s'", dev_id);

	cubeb_device_collection dev_collection{};
	if (int err = cubeb_enumerate_devices(m_ctx, CUBEB_DEVICE_TYPE_OUTPUT, &dev_collection))
	{
		Cubeb.error("cubeb_enumerate_devices() failed: %i", err);
		return {};
	}

	if (dev_collection.count == 0)
	{
		Cubeb.error("No output devices available");
		if (int err = cubeb_device_collection_destroy(m_ctx, &dev_collection))
		{
			Cubeb.error("cubeb_device_collection_destroy() failed: %i", err);
		}
		return {};
	}

	Cubeb.notice("Found %d possible output devices", dev_collection.count);

	device_handle result{};

	for (u64 dev_idx = 0; dev_idx < dev_collection.count; dev_idx++)
	{
		const cubeb_device_info& dev_info = dev_collection.device[dev_idx];

		device_handle device{};
		device.handle = dev_info.devid;
		device.ch_cnt = dev_info.max_channels;

		if (dev_info.device_id)
		{
			device.id = dev_info.device_id;
		}

		if (device.id.empty())
		{
			Cubeb.error("device_id is missing from device");
			continue;
		}

		if (default_dev)
		{
			if (dev_info.preferred & CUBEB_DEVICE_PREF_MULTIMEDIA)
			{
				result = std::move(device);
				break;
			}
		}
		else if (device.id == dev_id)
		{
			result = std::move(device);
			break;
		}
	}

	if (result.handle)
	{
		Cubeb.notice("Found device '%s' with %d channels", result.id, result.ch_cnt);
	}
	else
	{
		Cubeb.notice("No device found for dev_id='%s'", dev_id);
	}

	if (int err = cubeb_device_collection_destroy(m_ctx, &dev_collection))
	{
		Cubeb.error("cubeb_device_collection_destroy() failed: %i", err);
	}

	return result;
};

CubebBackend::device_handle CubebBackend::GetDefaultDeviceAlt(AudioFreq freq, AudioSampleSize sample_size, u32 ch_cnt)
{
	Cubeb.notice("Starting alternative search for default device with freq=%d, sample_size=%d and ch_cnt=%d", static_cast<u32>(freq), static_cast<u32>(sample_size), static_cast<u32>(ch_cnt));

	cubeb_stream_params param =
	{
		.format   = sample_size == AudioSampleSize::S16 ? CUBEB_SAMPLE_S16NE : CUBEB_SAMPLE_FLOAT32NE,
		.rate     = static_cast<u32>(freq),
		.channels = static_cast<u32>(ch_cnt),
		.layout   = CUBEB_LAYOUT_UNDEFINED,
		.prefs    = CUBEB_STREAM_PREF_DISABLE_DEVICE_SWITCHING
	};

	u32 min_latency{};
	if (int err = cubeb_get_min_latency(m_ctx, &param, &min_latency))
	{
		Cubeb.error("cubeb_get_min_latency() failed: %i", err);
		min_latency = 100;
	}

	cubeb_stream* tmp_stream{};
	static auto dummy_data_cb = [](cubeb_stream*, void*, void const*, void*, long) -> long { return 0; };
	static auto dummy_state_cb = [](cubeb_stream*, void*, cubeb_state) {};

	if (int err = cubeb_stream_init(m_ctx, &tmp_stream, "Default device detector", nullptr, nullptr, nullptr, &param, min_latency, dummy_data_cb, dummy_state_cb, nullptr))
	{
		Cubeb.error("cubeb_stream_init() failed: %i", err);
		return {};
	}

	cubeb_device* crnt_dev{};

	if (int err = cubeb_stream_get_current_device(tmp_stream, &crnt_dev); err != CUBEB_OK || !crnt_dev)
	{
		Cubeb.error("cubeb_stream_get_current_device() failed: err=%i, crnt_dev=%d", err, !!crnt_dev);
		cubeb_stream_destroy(tmp_stream);
		return {};
	}

	std::string out_dev_name;

	if (crnt_dev->output_name)
	{
		out_dev_name = crnt_dev->output_name;
	}

	if (int err = cubeb_stream_device_destroy(tmp_stream, crnt_dev))
	{
		Cubeb.error("cubeb_stream_device_destroy() failed: %i", err);
	}

	cubeb_stream_destroy(tmp_stream);

	if (out_dev_name.empty())
	{
		Cubeb.notice("No default device available");
		return {};
	}

	return GetDevice(out_dev_name);
}

long CubebBackend::data_cb(cubeb_stream* stream, void* user_ptr, void const* /* input_buffer */, void* output_buffer, long nframes)
{
	if (nframes <= 0)
	{
		Cubeb.error("data_cb called with nframes=%d", nframes);
		return 0;
	}

	if (!output_buffer)
	{
		Cubeb.error("data_cb called with invalid output_buffer");
		return CUBEB_ERROR;
	}

	if (!stream)
	{
		Cubeb.error("data_cb called with invalid stream");
		return CUBEB_ERROR;
	}

	CubebBackend* const cubeb = static_cast<CubebBackend*>(user_ptr);
	ensure(cubeb);
#if defined(__ANDROID__)
	static std::atomic<std::uint64_t> gd_cb_count{0};
	static std::atomic<std::uint64_t> gd_last_cb_ns{0};
	const bool gd_trace_cb = gamedeck_trace::enabled();
	const std::uint64_t gd_cb_n = gd_cb_count.fetch_add(1, std::memory_order_relaxed) + 1;
	const std::uint64_t gd_cb_now_ns = gd_trace_cb ? gamedeck_trace::now_ns() : 0;
	const std::uint64_t gd_cb_prev_ns = gd_trace_cb ? gd_last_cb_ns.exchange(gd_cb_now_ns, std::memory_order_relaxed) : 0;
	const std::uint64_t gd_cb_gap_us = gd_cb_prev_ns ? (gd_cb_now_ns - gd_cb_prev_ns) / 1000 : 0;
	u32 gd_written_bytes = 0;
	const u32 gd_bytes_req = static_cast<u32>(nframes) * cubeb->full_sample_size.observe();
#endif

	std::unique_lock lock(cubeb->m_cb_mutex, std::defer_lock);

	if (!cubeb->m_reset_req.observe() && lock.try_lock_for(std::chrono::microseconds{50}) && cubeb->m_write_callback && cubeb->m_playing)
	{
		if (stream != cubeb->m_stream)
		{
			// Cubeb.error("data_cb called with unknown stream");
			return CUBEB_ERROR;
		}

		const u32 sample_size = cubeb->full_sample_size.observe();
		const u32 bytes_req = nframes * sample_size;
		u32 written = std::min(cubeb->m_write_callback(bytes_req, output_buffer), bytes_req);
		written -= written % sample_size;
#if defined(__ANDROID__)
		gd_written_bytes = written;
#endif

		if (written >= sample_size)
		{
			memcpy(cubeb->m_last_sample.data(), static_cast<u8*>(output_buffer) + written - sample_size, sample_size);
		}

		for (u32 i = written; i < bytes_req; i += sample_size)
		{
			memcpy(static_cast<u8*>(output_buffer) + i, cubeb->m_last_sample.data(), sample_size);
		}
	}
	else
	{
		// Stream parameters are modified only after stream_destroy. stream_destroy will return
		// only after this callback returns, so it's safe to access full_sample_size here.
		memset(output_buffer, 0, nframes * cubeb->full_sample_size);
	}

#if defined(__ANDROID__)
	if (gd_trace_cb && gd_cb_gap_us >= 35000)
	{
		gamedeck_trace::emit("cubeb_callback_gap", "count=%llu\tgap_us=%llu\tnframes=%ld\tplaying=%u\treset=%u", static_cast<unsigned long long>(gd_cb_n), static_cast<unsigned long long>(gd_cb_gap_us), nframes, cubeb->m_playing ? 1u : 0u, cubeb->m_reset_req.observe() ? 1u : 0u);
	}
	if (gd_trace_cb && (gd_cb_n <= 8 || (gd_cb_n % 32) == 0))
	{
		const u32 channels = std::min<u32>(cubeb->get_channels(), AUDIO_MAX_CHANNELS);
		const u64 scalar_count = static_cast<u64>(nframes) * channels;
		u64 zero_count = 0;
		u64 clip_count = 0;
		u64 invalid_count = 0;
		u32 peak_permille = 0;
		u32 step_permille = 0;

		if (scalar_count && cubeb->get_convert_to_s16())
		{
			static thread_local s16 gd_prev[AUDIO_MAX_CHANNELS]{};
			static thread_local bool gd_prev_valid = false;
			const s16* samples = static_cast<const s16*>(output_buffer);
			u32 peak = 0;
			u32 max_step = 0;
			for (long frame = 0; frame < nframes; frame++)
			{
				for (u32 ch = 0; ch < channels; ch++)
				{
					const int v = samples[static_cast<u64>(frame) * channels + ch];
					const u32 av = static_cast<u32>(v < 0 ? -v : v);
					peak = std::max(peak, av);
					zero_count += (v == 0);
					clip_count += (av >= 32760);
					if (gd_prev_valid)
					{
						const int delta = v - static_cast<int>(gd_prev[ch]);
						max_step = std::max(max_step, static_cast<u32>(delta < 0 ? -delta : delta));
					}
					gd_prev[ch] = static_cast<s16>(v);
				}
			}
			gd_prev_valid = true;
			peak_permille = (peak * 1000u) / 32768u;
			step_permille = (max_step * 1000u) / 65535u;
		}
		else if (scalar_count)
		{
			static thread_local f32 gd_prev[AUDIO_MAX_CHANNELS]{};
			static thread_local bool gd_prev_valid = false;
			const f32* samples = static_cast<const f32*>(output_buffer);
			f64 peak = 0.0;
			f64 max_step = 0.0;
			for (long frame = 0; frame < nframes; frame++)
			{
				for (u32 ch = 0; ch < channels; ch++)
				{
					const f32 v = samples[static_cast<u64>(frame) * channels + ch];
					if (!std::isfinite(v))
					{
						invalid_count++;
						continue;
					}
					const f64 av = std::fabs(static_cast<f64>(v));
					peak = std::max(peak, av);
					zero_count += (av < 1e-7);
					clip_count += (av >= 0.999);
					if (gd_prev_valid && std::isfinite(gd_prev[ch]))
					{
						max_step = std::max(max_step, std::fabs(static_cast<f64>(v) - gd_prev[ch]));
					}
					gd_prev[ch] = v;
				}
			}
			gd_prev_valid = true;
			peak_permille = static_cast<u32>(std::min<f64>(9999.0, peak * 1000.0));
			step_permille = static_cast<u32>(std::min<f64>(9999.0, max_step * 500.0));
		}

		const u32 fill_bytes = gd_bytes_req > gd_written_bytes ? gd_bytes_req - gd_written_bytes : 0;
		const u32 zero_permille = scalar_count ? static_cast<u32>((zero_count * 1000ull) / scalar_count) : 0;
		const u32 clip_permille = scalar_count ? static_cast<u32>((clip_count * 1000ull) / scalar_count) : 0;
		const u32 invalid_permille = scalar_count ? static_cast<u32>((invalid_count * 1000ull) / scalar_count) : 0;
		const u32 fill_permille = gd_bytes_req ? (fill_bytes * 1000u) / gd_bytes_req : 0;
		gamedeck_trace::emit("cubeb_output_stats",
			"count=%llu\tnframes=%ld\tchannels=%u\ts16=%u\tpeak_pm=%u\tzero_pm=%u\tclip_pm=%u\tinvalid_pm=%u\tstep_pm=%u\twritten_bytes=%u\tfill_bytes=%u\tfill_pm=%u",
			static_cast<unsigned long long>(gd_cb_n), nframes, channels, cubeb->get_convert_to_s16() ? 1u : 0u, peak_permille, zero_permille, clip_permille, invalid_permille, step_permille, gd_written_bytes, fill_bytes, fill_permille);
	}
#endif
	return nframes;
}

void CubebBackend::state_cb(cubeb_stream* stream, void* user_ptr, cubeb_state state)
{
	if (!stream)
	{
		Cubeb.error("state_cb called with invalid stream");
		return;
	}

	CubebBackend* const cubeb = static_cast<CubebBackend*>(user_ptr);
	ensure(cubeb);

	std::lock_guard lock(cubeb->m_state_cb_mutex);

	if (stream != cubeb->m_stream)
	{
		Cubeb.error("state_cb called with unknown stream");
		return;
	}

	switch (state)
	{
	case CUBEB_STATE_ERROR:
	{
		Cubeb.error("Stream entered error state");

		if (!cubeb->m_reset_req.test_and_set() && cubeb->m_state_callback)
		{
			cubeb->m_state_callback(AudioStateEvent::UNSPECIFIED_ERROR);
		}

		break;
	}
	case CUBEB_STATE_STARTED:
	{
		Cubeb.notice("Stream started");
		break;
	}
	case CUBEB_STATE_STOPPED:
	{
		Cubeb.notice("Stream stopped");
		break;
	}
	case CUBEB_STATE_DRAINED:
	{
		Cubeb.notice("Stream drained");
		break;
	}
	default:
	{
		Cubeb.notice("Stream entered unknown state %d", static_cast<u32>(state));
		break;
	}
	}
}

void CubebBackend::device_collection_changed_cb(cubeb* context, void* user_ptr)
{
	Cubeb.notice("Device collection changed");

	if (!context)
	{
		Cubeb.error("device_collection_changed_cb called with invalid stream");
		return;
	}

	CubebBackend* const cubeb = static_cast<CubebBackend*>(user_ptr);
	ensure(cubeb);

	if (cubeb->m_reset_req.observe())
	{
		return;
	}

	std::lock_guard cb_lock{cubeb->m_state_cb_mutex};

	if (context != cubeb->m_ctx)
	{
		Cubeb.error("device_collection_changed_cb called with unknown context");
		return;
	}

	// Non default device is used (or default device cannot be detected)
	if (cubeb->m_default_device.empty())
	{
		Cubeb.notice("Skipping default device notification");
		return;
	}

	if (cubeb->m_state_callback)
	{
		cubeb->m_state_callback(AudioStateEvent::DEFAULT_DEVICE_MAYBE_CHANGED);
	}
}

void CubebBackend::log_cb(const char* fmt, ...)
{
	char buf[256]{};

	va_list va;
	va_start(va, fmt);
	vsnprintf(buf, sizeof(buf) - 1, fmt, va);
	va_end(va);

	Cubeb.notice("Cubeb log: %s", buf);
}
