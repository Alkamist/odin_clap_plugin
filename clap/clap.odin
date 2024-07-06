package clap

import "core:c"

NAME_SIZE :: 256
PATH_SIZE :: 1024
CORE_EVENT_SPACE_ID :: 0
PLUGIN_FACTORY_ID :: "clap.plugin-factory"
EXT_AUDIO_PORTS :: "clap.audio-ports"
EXT_NOTE_PORTS :: "clap.note-ports"
EXT_LATENCY :: "clap.latency"
EXT_PARAMS :: "clap.params"
EXT_TIMER_SUPPORT :: "clap.timer-support"
EXT_STATE :: "clap.state"
EXT_GUI :: "clap.gui"
EXT_LOG :: "clap.log"

WINDOW_API_WIN32 :: "win32"
WINDOW_API_COCOA :: "cocoa"
WINDOW_API_X11 :: "x11"
WINDOW_API_WAYLAND :: "wayland"
when ODIN_OS == .Windows {
	WINDOW_API :: WINDOW_API_WIN32
} else when ODIN_OS == .Darwin {
	WINDOW_API :: WINDOW_API_COCOA
} else when ODIN_OS == .Linux {
	WINDOW_API :: WINDOW_API_X11
}

PLUGIN_FEATURE_INSTRUMENT :: "instrument"
PLUGIN_FEATURE_AUDIO_EFFECT :: "audio-effect"
PLUGIN_FEATURE_NOTE_EFFECT :: "note-effect"
PLUGIN_FEATURE_NOTE_DETECTOR :: "note-detector"
PLUGIN_FEATURE_ANALYZER :: "analyzer"
PLUGIN_FEATURE_SYNTHESIZER :: "synthesizer"
PLUGIN_FEATURE_SAMPLER :: "sampler"
PLUGIN_FEATURE_DRUM :: "drum"
PLUGIN_FEATURE_DRUM_MACHINE :: "drum-machine"
PLUGIN_FEATURE_FILTER :: "filter"
PLUGIN_FEATURE_PHASER :: "phaser"
PLUGIN_FEATURE_EQUALIZER :: "equalizer"
PLUGIN_FEATURE_DEESSER :: "de-esser"
PLUGIN_FEATURE_PHASE_VOCODER :: "phase-vocoder"
PLUGIN_FEATURE_GRANULAR :: "granular"
PLUGIN_FEATURE_FREQUENCY_SHIFTER :: "frequency-shifter"
PLUGIN_FEATURE_PITCH_SHIFTER :: "pitch-shifter"
PLUGIN_FEATURE_DISTORTION :: "distortion"
PLUGIN_FEATURE_TRANSIENT_SHAPER :: "transient-shaper"
PLUGIN_FEATURE_COMPRESSOR :: "compressor"
PLUGIN_FEATURE_EXPANDER :: "expander"
PLUGIN_FEATURE_GATE :: "gate"
PLUGIN_FEATURE_LIMITER :: "limiter"
PLUGIN_FEATURE_FLANGER :: "flanger"
PLUGIN_FEATURE_CHORUS :: "chorus"
PLUGIN_FEATURE_DELAY :: "delay"
PLUGIN_FEATURE_REVERB :: "reverb"
PLUGIN_FEATURE_TREMOLO :: "tremolo"
PLUGIN_FEATURE_GLITCH :: "glitch"
PLUGIN_FEATURE_UTILITY :: "utility"
PLUGIN_FEATURE_PITCH_CORRECTION :: "pitch-correction"
PLUGIN_FEATURE_RESTORATION :: "restoration"
PLUGIN_FEATURE_MULTI_EFFECTS :: "multi-effects"
PLUGIN_FEATURE_MIXING :: "mixing"
PLUGIN_FEATURE_MASTERING :: "mastering"
PLUGIN_FEATURE_MONO :: "mono"
PLUGIN_FEATURE_STEREO :: "stereo"
PLUGIN_FEATURE_SURROUND :: "surround"
PLUGIN_FEATURE_AMBISONIC :: "ambisonic"

INVALID_ID :: max(u32)
PORT_MONO ::"mono"
PORT_STEREO :: "stereo"

BEATTIME_FACTOR :: 1 << 31
SECTIME_FACTOR :: 1 << 31

id :: u32
beat_time :: i64
sec_time :: i64

version_is_compatible :: proc "c" (v: version_t) -> bool {
    return v.major >= 1;
}

// note_dialect :: enum u32 {
//     CLAP,
//     MIDI,
//     MIDI_MPE,
//     MIDI2,
// }

event_type :: enum u16 {
    NOTE_ON,
    NOTE_OFF,
    NOTE_CHOKE,
    NOTE_END,
    NOTE_EXPRESSION,
    PARAM_VALUE,
    PARAM_MOD,
    PARAM_GESTURE_BEGIN,
    PARAM_GESTURE_END,
    TRANSPORT,
    MIDI,
    MIDI_SYSEX,
    MIDI2,
}

event_header_t :: struct {
    size: u32,
    time: u32,
    space_id: u16,
    type: event_type,
    flags: u32,
}

event_param_value_t :: struct {
    header: event_header_t,
    param_id: id,
    cookie: rawptr,
    note_id: i32,
    port_index: i16,
    channel: i16,
    key: i16,
    value: f64,
}

event_param_gesture_t :: struct {
    header: event_header_t,
    param_id: id,
}

// event_midi :: struct {
//     header: event_header,
//     port_index: u16,
//     data: [3]u8,
// }

transport_event_flag :: enum {
    HAS_TEMPO,
    HAS_BEATS_TIMELINE,
    HAS_SECONDS_TIMELINE,
    HAS_TIME_SIGNATURE,
    IS_PLAYING,
    IS_RECORDING,
    IS_LOOP_ACTIVE,
    IS_WITHIN_PRE_ROLL,
}

event_transport_t :: struct {
    header: event_header_t,
    flags: bit_set[transport_event_flag; u32],
    song_pos_beats: beat_time,
    song_pos_seconds: sec_time,
    tempo: f64,
    tempo_inc: f64,
    loop_start_beats: beat_time,
    loop_end_beats: beat_time,
    loop_start_seconds: sec_time,
    loop_end_seconds: sec_time,
    bar_start: beat_time,
    bar_number: i32,
    tsig_num: u16,
    tsig_denom: u16,
}

audio_buffer_t :: struct {
    data32: [^][^]f32,
    data64: [^][^]f64,
    channel_count: u32,
    latency: u32,
    constant_mask: u64,
}

input_events_t :: struct {
    ctx: rawptr,
    size: proc "c" (list: ^input_events_t) -> u32,
    get: proc "c" (list: ^input_events_t, index: u32) -> ^event_header_t,
}

output_events_t :: struct {
    ctx: rawptr,
    try_push: proc "c" (list: ^output_events_t, event: ^event_header_t) -> bool,
}

process_status :: enum i32 {
    ERROR,
    CONTINUE,
    CONTINUE_IF_NOT_QUIET,
    TAIL,
    SLEEP,
}

gui_resize_hints_t :: struct{
    can_resize_horizontally: bool,
    can_resize_vertically: bool,
    preserve_aspect_ratio: bool,
    aspect_ratio_width: u32,
    aspect_ratio_height: u32,
}

window_t :: struct {
    api: cstring,
    handle: rawptr,
}

plugin_gui_t :: struct{
    is_api_supported: proc "c" (plugin: ^plugin_t, api: cstring, is_floating: bool) -> bool,
    get_preferred_api: proc "c" (plugin: ^plugin_t, api: ^cstring, is_floating: ^bool) -> bool,
    create: proc "c" (plugin: ^plugin_t, api: cstring, is_floating: bool) -> bool,
    destroy: proc "c" (plugin: ^plugin_t),
    set_scale: proc "c" (plugin: ^plugin_t, scale: f64) -> bool,
    get_size: proc "c" (plugin: ^plugin_t, width, height: ^u32) -> bool,
    can_resize: proc "c" (plugin: ^plugin_t) -> bool,
    get_resize_hints: proc "c" (plugin: ^plugin_t, hints: ^gui_resize_hints_t) -> bool,
    adjust_size: proc "c" (plugin: ^plugin_t, width, height: ^u32) -> bool,
    set_size: proc "c" (plugin: ^plugin_t, width, height: u32) -> bool,
    set_parent: proc "c" (plugin: ^plugin_t, window: ^window_t) -> bool,
    set_transient: proc "c" (plugin: ^plugin_t, window: ^window_t) -> bool,
    suggest_title: proc "c" (plugin: ^plugin_t, title: cstring),
    show: proc "c" (plugin: ^plugin_t) -> bool,
    hide: proc "c" (plugin: ^plugin_t) -> bool,
}

// host_latency :: struct {
//     changed: proc "c" (host: ^host),
// }

// plugin_latency :: struct {
//     get: proc "c" (plugin: ^plugin_t) -> u32,
// }

process_t :: struct {
    steady_time: i64,
    frames_count: u32,
    transport: ^event_transport_t,
    audio_inputs: [^]audio_buffer_t,
    audio_outputs: [^]audio_buffer_t,
    audio_inputs_count: u32,
    audio_outputs_count: u32,
    in_events: ^input_events_t,
    out_events: ^output_events_t,
}

// note_port_info :: struct {
//     id: Id,
//     supported_dialects: bit_set[note_dialect; u32],
//     preferred_dialect: bit_set[note_dialect; u32],
//     name: [NAME_SIZE]byte,
// }

// plugin_note_ports :: struct {
//     count: proc "c" (plugin: ^plugin_t, is_input: bool) -> u32,
//     get: proc "c" (plugin: ^plugin_t, index: u32, is_input: bool, info: ^note_port_info) -> bool,
// }

// istream :: struct {
//     ctx: rawptr,
//     read: proc "c" (stream: ^istream, buffer: rawptr, size: u64) -> i64,
// }

// ostream :: struct {
//     ctx: rawptr,
//     write: proc "c" (stream: ^ostream, buffer: rawptr, size: u64) -> i64,
// }

// Plugin_State :: struct {
//     save: proc "c" (plugin: ^plugin_t, stream: ^ostream) -> bool,
//     load: proc "c" (plugin: ^plugin_t, stream: ^istream) -> bool,
// }

// Log_Severity :: enum {
//     Debug,
//     Info,
//     Warning,
//     Error,
//     Fatal,
//     Host_Misbehaving,
//     Plugin_Misbehaving,
// }

// Host_Log :: struct {
//     log: proc "c" (host: ^host, severity: Log_Severity, msg: cstring),
// }

param_info_flag :: enum u32 {
    IS_STEPPED,
    IS_PERIODIC,
    IS_HIDDEN,
    IS_READ_ONLY,
    IS_BYPASS,
    IS_AUTOMATABLE,
    IS_AUTOMATABLE_PER_NOTE_ID,
    IS_AUTOMATABLE_PER_KEY,
    IS_AUTOMATABLE_PER_CHANNEL,
    IS_AUTOMATABLE_PER_PORT,
    IS_MODULATABLE,
    IS_MODULATABLE_PER_NOTE_ID,
    IS_MODULATABLE_PER_KEY,
    IS_MODULATABLE_PER_CHANNEL,
    IS_MODULATABLE_PER_PORT,
    REQUIRES_PROCESS,
}

param_info_t :: struct {
    id: u32,
    flags: bit_set[param_info_flag; u32],
    cookie: rawptr,
    name: [NAME_SIZE]byte,
    module: [PATH_SIZE]byte,
    min_value: f64,
    max_value: f64,
    default_value: f64,
}

plugin_params_t :: struct {
    count: proc "c" (plugin: ^plugin_t) -> u32,
    get_info: proc "c" (plugin: ^plugin_t, param_index: u32, param_info: ^param_info_t) -> bool,
    get_value: proc "c" (plugin: ^plugin_t, param_id: id, out_value: ^f64) -> bool,
    value_to_text: proc "c" (plugin: ^plugin_t, param_id: id, value: f64, out_buffer: [^]byte, out_buffer_capacity: u32) -> bool,
    text_to_value: proc "c" (plugin: ^plugin_t, param_id: id, param_value_text: cstring, out_value: ^f64) -> bool,
    flush: proc "c" (plugin: ^plugin_t, input: ^input_events_t, output: ^output_events_t),
}

audio_port_flag :: enum u32 {
    IS_MAIN,
    SUPPORTS_64BITS,
    PREFERS_64BITS,
    REQUIRES_COMMON_SAMPLE_SIZE,
}

audio_port_info_t :: struct {
    id: u32,
    name: [NAME_SIZE]u8,
    flags: bit_set[audio_port_flag; u32],
    channel_count: u32,
    port_type: string,
    in_place_pair: u32,
}

plugin_audio_ports_t :: struct {
    count: proc "c" (plugin: ^plugin_t, is_input: bool) -> u32,
    get: proc "c" (plugin: ^plugin_t, index: u32, is_input: bool, info: ^audio_port_info_t) -> bool,
}

plugin_descriptor_t :: struct {
    clap_version: version_t,
    id: cstring,
    name: cstring,
    vendor: cstring,
    url: cstring,
    manual_url: cstring,
    support_url: cstring,
    version: cstring,
    description: cstring,
    features: [^]cstring,
}

plugin_t :: struct {
    desc: ^plugin_descriptor_t,
    plugin_data: rawptr,
    init: proc "c" (plugin: ^plugin_t) -> bool,
    destroy: proc "c" (plugin: ^plugin_t),
    activate: proc "c" (plugin: ^plugin_t, sample_rate: f64, min_frames_count, max_frames_count: u32) -> bool,
    deactivate: proc "c" (plugin: ^plugin_t),
    start_processing: proc "c" (plugin: ^plugin_t) -> bool,
    stop_processing: proc "c" (plugin: ^plugin_t),
    reset: proc "c" (plugin: ^plugin_t),
    process: proc "c" (plugin: ^plugin_t, process: ^process_t) -> process_status,
    get_extension: proc "c" (plugin: ^plugin_t, id: cstring) -> rawptr,
    on_main_thread: proc "c" (plugin: ^plugin_t),
}

version_t :: struct {
    major: u32,
    minor: u32,
    revision: u32,
}

plugin_timer_support_t :: struct {
    on_timer: proc "c" (plugin: ^plugin_t, timer_id: id),
}

host_timer_support_t :: struct {
    register_timer: proc "c" (host: ^host_t, period_ms: u32, timer_id: ^id) -> bool,
    unregister_timer: proc "c" (host: ^host_t, timer_id: id) -> bool,
}

host_t :: struct {
    clap_version: version_t,
    host_data: rawptr,
    name: cstring,
    vendor: cstring,
    url: cstring,
    version: cstring,
    get_extension: proc "c" (host: ^host_t, extension_id: cstring) -> rawptr,
    request_restart: proc "c" (host: ^host_t),
    request_process: proc "c" (host: ^host_t),
    request_callback: proc "c" (host: ^host_t),
}

plugin_factory_t :: struct {
    get_plugin_count: proc "c" (factory: ^plugin_factory_t) -> u32,
    get_plugin_descriptor: proc "c" (factory: ^plugin_factory_t, index: u32) -> ^plugin_descriptor_t,
    create_plugin: proc "c" (factory: ^plugin_factory_t, host: ^host_t, plugin_id: cstring) -> ^plugin_t,
}

plugin_entry_t :: struct {
    clap_version: version_t,
    init: proc "c" (plugin_path: cstring) -> bool,
    deinit: proc "c" (),
    get_factory: proc "c" (factory_id: cstring) -> rawptr,
}