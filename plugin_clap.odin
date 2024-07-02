package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:sync"
import "core:slice"
import "core:strings"
import "core:strconv"
import "clap"

CLAP_VERSION :: clap.version_t{1, 2, 1}

clap_plugin_descriptor := clap.plugin_descriptor_t{
    clap_version = CLAP_VERSION,
    id = "com.alkamist.TestPlugin",
    name = "Test Plugin",
    vendor = "Alkamist Audio",
    url = "",
    manual_url = "",
    support_url = "",
    version = "0.1.0",
    description = "",
    features = raw_data([]cstring{
        clap.PLUGIN_FEATURE_AUDIO_EFFECT,
        nil,
    }),
}

main_context: runtime.Context

_debug_string_mutex: sync.Mutex
_debug_string_builder: strings.Builder
_debug_string_changed: bool

Clap_Event_Union :: union {
    clap.event_param_value_t,
}

Plugin_Base :: struct {
    clap_host: ^clap.host_t,
    clap_plugin: clap.plugin_t,
    parameter_values: [Parameter]f64,
    output_events: [dynamic]Clap_Event_Union,
    output_event_mutex: sync.Mutex,
}

//==========================================================================
// Plugin
//==========================================================================

clap_plugin_init :: proc "c" (plugin: ^clap.plugin_t) -> bool {
    context = main_context
    plugin := cast(^Plugin)(plugin.plugin_data)

    plugin_init(plugin)
    register_timer(plugin, 0, 0)

    return true
}

clap_plugin_destroy :: proc "c" (plugin: ^clap.plugin_t) {
    context = main_context
    plugin := cast(^Plugin)(plugin.plugin_data)
    plugin_destroy(plugin)
    unregister_timer(plugin, 0)
    delete(plugin.output_events)
    free(plugin)
}

clap_plugin_activate :: proc "c" (plugin: ^clap.plugin_t, sample_rate: f64, min_frames_count, max_frames_count: u32) -> bool {
    context = main_context
    plugin := cast(^Plugin)(plugin.plugin_data)
    plugin_activate(plugin, sample_rate, int(min_frames_count), int(max_frames_count))
    return true
}

clap_plugin_deactivate :: proc "c" (plugin: ^clap.plugin_t) {
    context = main_context
    plugin := cast(^Plugin)(plugin.plugin_data)
    plugin_deactivate(plugin)
}

clap_plugin_start_processing :: proc "c" (plugin: ^clap.plugin_t) -> bool {
    context = main_context
    plugin := cast(^Plugin)(plugin.plugin_data)
    plugin_start_processing(plugin)
    return true
}

clap_plugin_stop_processing :: proc "c" (plugin: ^clap.plugin_t) {
    context = main_context
    plugin := cast(^Plugin)(plugin.plugin_data)
    plugin_stop_processing(plugin)
}

clap_plugin_reset :: proc "c" (plugin: ^clap.plugin_t) {
    context = main_context
    plugin := cast(^Plugin)(plugin.plugin_data)
    plugin_reset(plugin)
}

clap_plugin_process :: proc "c" (plugin: ^clap.plugin_t, process: ^clap.process_t) -> clap.process_status {
    context = main_context
    plugin := cast(^Plugin)(plugin.plugin_data)

    frame_count := process.frames_count
    event_count := process.in_events->size()
    event_index: u32 = 0

    for frame in 0 ..< frame_count {
        for event_index < event_count {
            event_header := process.in_events->get(event_index)
            if event_header.time != frame {
                break
            }

            if event_header.space_id == clap.CORE_EVENT_SPACE_ID {
                clap_dispatch_parameter_event(plugin, event_header)
            }

            event_index += 1
        }

        gain := parameter(plugin, .Gain)

        in_l := process.audio_inputs[0].data64[0][frame]
        in_r := process.audio_inputs[0].data64[1][frame]

        out_l := in_l * gain
        out_r := in_r * gain

        process.audio_outputs[0].data64[0][frame] = out_l
        process.audio_outputs[0].data64[1][frame] = out_r
    }

    // Sort and send output events, then clear the buffer.
    sync.lock(&plugin.output_event_mutex)
    slice.sort_by(plugin.output_events[:], proc(i, j: Clap_Event_Union) -> bool {
        i := i
        j := j
        i_header := cast(^clap.event_header_t)&i
        j_header := cast(^clap.event_header_t)&j
        return i_header.time < j_header.time
    })
    for &event in plugin.output_events {
        process.out_events->try_push(cast(^clap.event_header_t)&event)
    }
    clear(&plugin.output_events)
    sync.unlock(&plugin.output_event_mutex)

    return .CONTINUE
}

clap_plugin_get_extension :: proc "c" (plugin: ^clap.plugin_t, id: cstring) -> rawptr {
    switch id {
    case clap.EXT_AUDIO_PORTS: return &clap_extension_audio_ports
    // case clap.EXT_NOTE_PORTS: return &clap_extension_note_ports
    // case clap.EXT_LATENCY: return &clap_extension_latency
    case clap.EXT_PARAMS: return &clap_extension_parameters
    case clap.EXT_TIMER_SUPPORT: return &clap_extension_timer
    // case clap.EXT_STATE: return &clap_extension_state
    case clap.EXT_GUI: return &clap_extension_gui
    case: return nil
    }
}

clap_plugin_on_main_thread :: proc "c" (plugin: ^clap.plugin_t) {
}

//==========================================================================
// Timer Extension
//==========================================================================

clap_extension_timer := clap.plugin_timer_support_t{
    on_timer = proc "c" (plugin: ^clap.plugin_t, timer_id: clap.id) {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)

        // Flush the debug string to Reaper console.
        sync.lock(&_debug_string_mutex)
        if _debug_string_changed {
            reaper_plugin_info_t :: struct {
                caller_version: c.int,
                hwnd_main: rawptr,
                Register: proc "c" (name: cstring, infostruct: rawptr) -> c.int,
                GetFunc: proc "c" (name: cstring) -> rawptr,
            }
            plugin_info := cast(^reaper_plugin_info_t)plugin.clap_host->get_extension("cockos.reaper_extension")
            ShowConsoleMsg := cast(proc "c" (msg: cstring))plugin_info.GetFunc("ShowConsoleMsg")
            ShowConsoleMsg(strings.clone_to_cstring(strings.to_string(_debug_string_builder), context.temp_allocator))
            strings.builder_reset(&_debug_string_builder)
            _debug_string_changed = false
        }
        sync.unlock(&_debug_string_mutex)

        free_all(context.temp_allocator)
    },
}

//==========================================================================
// Note Ports Extension
//==========================================================================

clap_extension_audio_ports := clap.plugin_audio_ports_t{
    count = proc "c" (plugin: ^clap.plugin_t, is_input: bool) -> u32 {
        return 1
    },
    get = proc "c" (plugin: ^clap.plugin_t, index: u32, is_input: bool, info: ^clap.audio_port_info_t) -> bool {
        if index > 0 {
            return false
        }
        info.id = 0
        write_string_null_terminated(info.name[:], "Audio Port 1")
        info.channel_count = 2
        info.flags = {.IS_MAIN, .SUPPORTS_64BITS, .PREFERS_64BITS}
        info.port_type = clap.PORT_STEREO
        info.in_place_pair = clap.INVALID_ID
        return true
    },
}

//==========================================================================
// Parameter Extension
//==========================================================================

clap_dispatch_parameter_event :: proc(plugin: ^Plugin, event_header: ^clap.event_header_t) {
    #partial switch event_header.type {
    case .PARAM_VALUE:
        clap_event := cast(^clap.event_param_value_t)event_header
        sync.atomic_store(&plugin.parameter_values[Parameter(clap_event.param_id)], clap_event.value)
    }
}

clap_extension_parameters := clap.plugin_params_t{
    count = proc "c" (plugin: ^clap.plugin_t) -> u32 {
        plugin := cast(^Plugin)(plugin.plugin_data)
        return len(Parameter)
    },
    get_info = proc "c" (plugin: ^clap.plugin_t, param_index: u32, param_info: ^clap.param_info_t) -> bool {
        plugin := cast(^Plugin)(plugin.plugin_data)
        if len(Parameter) == 0 {
            return false
        }
        param_info^ = parameter_info[param_index]
        return true
    },
    get_value = proc "c" (plugin: ^clap.plugin_t, param_id: clap.id, out_value: ^f64) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        if len(Parameter) == 0 {
            return false
        }
        out_value^ = parameter(plugin, Parameter(param_id))
        return true
    },
    value_to_text = proc "c" (plugin: ^clap.plugin_t, param_id: clap.id, value: f64, out_buffer: [^]byte, out_buffer_capacity: u32) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        if len(Parameter) == 0 {
            return false
        }
        value_string := fmt.tprintf("%v", value)
        write_string_null_terminated(out_buffer[:out_buffer_capacity], value_string)
        return true
    },
    text_to_value = proc "c" (plugin: ^clap.plugin_t, param_id: clap.id, param_value_text: cstring, out_value: ^f64) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        if len(Parameter) == 0 {
            return false
        }
        value, ok := strconv.parse_f64(cast(string)param_value_text)
        if ok {
            out_value^ = value
            return true
        } else {
            return false
        }
    },
    flush = proc "c" (plugin: ^clap.plugin_t, input: ^clap.input_events_t, output: ^clap.output_events_t) {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        event_count := input->size()
        for i in 0 ..< event_count {
            clap_dispatch_parameter_event(plugin, input->get(i))
        }
    },
}

//==========================================================================
// Gui Extension
//==========================================================================

clap_extension_gui := clap.plugin_gui_t{
    is_api_supported = proc "c" (plugin: ^clap.plugin_t, api: cstring, is_floating: bool) -> bool {
        return api == clap.WINDOW_API && !is_floating
    },
    get_preferred_api = proc "c" (plugin: ^clap.plugin_t, api: ^cstring, is_floating: ^bool) -> bool {
        api^ = clap.WINDOW_API
        is_floating^ = false
        return true
    },
    create = proc "c" (plugin: ^clap.plugin_t, api: cstring, is_floating: bool) -> bool {
        if !(api == clap.WINDOW_API && !is_floating) {
            return false
        }
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        plugin_gui_init(plugin)
		return true
    },
    destroy = proc "c" (plugin: ^clap.plugin_t) {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        plugin_gui_destroy(plugin)
    },
    set_scale = proc "c" (plugin: ^clap.plugin_t, scale: f64) -> bool {
        return false
    },
    get_size = proc "c" (plugin: ^clap.plugin_t, width, height: ^u32) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        x, y := plugin_gui_size(plugin)
        width^ = u32(x)
        height^ = u32(y)
        return true
    },
    can_resize = proc "c" (plugin: ^clap.plugin_t) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        hints := plugin_gui_resize_hints(plugin)
        return hints.can_resize_horizontally || hints.can_resize_vertically
    },
    get_resize_hints = proc "c" (plugin: ^clap.plugin_t, hints: ^clap.gui_resize_hints_t) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        h := plugin_gui_resize_hints(plugin)
        hints.can_resize_horizontally = h.can_resize_horizontally
        hints.can_resize_vertically = h.can_resize_vertically
        hints.preserve_aspect_ratio = h.preserve_aspect_ratio
        hints.aspect_ratio_width = u32(h.aspect_ratio_width)
        hints.aspect_ratio_height = u32(h.aspect_ratio_height)
        return true
    },
    adjust_size = proc "c" (plugin: ^clap.plugin_t, width, height: ^u32) -> bool {
        return false
    },
    set_size = proc "c" (plugin: ^clap.plugin_t, width, height: u32) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        plugin_gui_set_size(plugin, int(width), int(height))
        return true
    },
    set_parent = proc "c" (plugin: ^clap.plugin_t, window: ^clap.window_t) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        plugin_gui_set_parent(plugin, window.handle)
        return true
    },
    set_transient = proc "c" (plugin: ^clap.plugin_t, window: ^clap.window_t) -> bool {
        return false
    },
    suggest_title = proc "c" (plugin: ^clap.plugin_t, title: cstring) {
    },
    show = proc "c" (plugin: ^clap.plugin_t) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        plugin_gui_show(plugin)
        return true
    },
    hide = proc "c" (plugin: ^clap.plugin_t) -> bool {
        context = main_context
        plugin := cast(^Plugin)(plugin.plugin_data)
        plugin_gui_hide(plugin)
        return true
    },
}

//==========================================================================
// Factory
//==========================================================================

clap_plugin_factory := clap.plugin_factory_t{
    get_plugin_count = proc "c" (factory: ^clap.plugin_factory_t) -> u32 {
        return 1
    },
    get_plugin_descriptor = proc "c" (factory: ^clap.plugin_factory_t, index: u32) -> ^clap.plugin_descriptor_t {
        return &clap_plugin_descriptor
    },
    create_plugin = proc "c" (factory: ^clap.plugin_factory_t, host: ^clap.host_t, plugin_id: cstring) -> ^clap.plugin_t {
        context = main_context
        if !clap.version_is_compatible(host.clap_version) {
            return nil
        }
        if plugin_id == clap_plugin_descriptor.id {
            plugin := new(Plugin)
            plugin.clap_host = host
            plugin.clap_plugin = {
                desc = &clap_plugin_descriptor,
                plugin_data = plugin,
                init = clap_plugin_init,
                destroy = clap_plugin_destroy,
                activate = clap_plugin_activate,
                deactivate = clap_plugin_deactivate,
                start_processing = clap_plugin_start_processing,
                stop_processing = clap_plugin_stop_processing,
                reset = clap_plugin_reset,
                process = clap_plugin_process,
                get_extension = clap_plugin_get_extension,
                on_main_thread = clap_plugin_on_main_thread,
            }
            return &plugin.clap_plugin
        }
        return nil
    },
}

//==========================================================================
// Entry
//==========================================================================

@export
clap_entry := clap.plugin_entry_t{
    clap_version = CLAP_VERSION,
    init = proc "c" (plugin_path: cstring) -> bool {
        main_context = runtime.default_context()
        context = main_context
        _debug_string_builder = strings.builder_make_none()
        return true
    },
    deinit = proc "c" () {
        context = main_context
        strings.builder_destroy(&_debug_string_builder)
    },
    get_factory = proc "c" (factory_id: cstring) -> rawptr {
        if factory_id == clap.PLUGIN_FACTORY_ID {
            return &clap_plugin_factory
        }
        return nil
    },
}

//==========================================================================
// Utility
//==========================================================================

parameter :: proc(plugin: ^Plugin, id: Parameter) -> f64 {
    return sync.atomic_load(&plugin.parameter_values[id])
}

set_parameter :: proc(plugin: ^Plugin, id: Parameter, value: f64) {
    previous_value := sync.atomic_load(&plugin.parameter_values[id])
    if value != previous_value {
        sync.atomic_store(&plugin.parameter_values[id], value)
        sync.lock(&plugin.output_event_mutex)
        append(&plugin.output_events, clap.event_param_value_t{
            header = {
                size = size_of(clap.event_param_value_t),
                time = 0,
                space_id = clap.CORE_EVENT_SPACE_ID,
                type = .PARAM_VALUE,
                flags = 0,
            },
            param_id = u32(id),
            cookie = nil,
            note_id = -1,
            port_index = -1,
            channel = -1,
            key = -1,
            value = value,
        })
        sync.unlock(&plugin.output_event_mutex)
    }
}

// reset_parameter :: proc "c" (plugin: ^Plugin, id: Parameter) {
//     set_parameter(plugin, id, parameter_info[id].default_value)
// }

println :: proc(args: ..any, sep := " ") {
    sync.lock(&_debug_string_mutex)
    strings.write_string(&_debug_string_builder, fmt.tprintln(..args, sep = sep))
    _debug_string_changed = true
    sync.unlock(&_debug_string_mutex)
}

printfln :: proc(format: string, args: ..any) {
    sync.lock(&_debug_string_mutex)
    strings.write_string(&_debug_string_builder, fmt.tprintfln(format, ..args))
    _debug_string_changed = true
    sync.unlock(&_debug_string_mutex)
}

register_timer :: proc(plugin: ^Plugin, id: clap.id, period_ms: int) {
    if plugin.clap_host == nil do return
    clap_host_timer_support := cast(^clap.host_timer_support_t)plugin.clap_host->get_extension(clap.EXT_TIMER_SUPPORT)
    if clap_host_timer_support == nil ||
       clap_host_timer_support.register_timer == nil {
        return
    }
    id := id
    clap_host_timer_support.register_timer(plugin.clap_host, u32(period_ms), &id)
}

unregister_timer :: proc(plugin: ^Plugin, id: clap.id) {
    if plugin.clap_host == nil do return
    clap_host_timer_support := cast(^clap.host_timer_support_t)plugin.clap_host->get_extension(clap.EXT_TIMER_SUPPORT)
    if clap_host_timer_support == nil ||
       clap_host_timer_support.register_timer == nil {
        return
    }
    clap_host_timer_support.unregister_timer(plugin.clap_host, id)
}

write_string_null_terminated :: proc "c" (buffer: []byte, value: string) {
    n := copy(buffer, value)
    // Make the buffer null terminated
    buffer[min(n, len(buffer) - 1)] = 0
}

clap_param_info :: proc(
    param: Parameter,
    name: string,
    min_value: f64,
    max_value: f64,
    default_value: f64,
    flags: bit_set[clap.param_info_flag; u32],
) -> (res: clap.param_info_t) {
    res.id = clap.id(Parameter.Gain)
    write_string_null_terminated(res.name[:], name)
    write_string_null_terminated(res.module[:], "")
    res.min_value = min_value
    res.max_value = max_value
    res.default_value = default_value
    res.flags = flags
    return
}