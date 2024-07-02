package main

import "core:sync"
import "core:thread"
import "core:strings"
import "clap"

// Figure out parameter smoothing
// Figure out FPS limit

default_font := Font{
    name = "consola_13",
    size = 13,
    data = #load("consola.ttf"),
}

Plugin_Window :: struct {
    using window: Window,
    plugin: ^Plugin,
}

Plugin :: struct {
    using base: Plugin_Base,

    window: Plugin_Window,
    gui_is_running: bool,
    gui_thread: ^thread.Thread,

    sample_rate: f64,
    min_frames: int,
    max_frames: int,

    gain_slider: Slider,
    test_text: strings.Builder,
    test_text_line: Editable_Text_Line,

    // box: Rectangle,
    // box_velocity: Vector2,
}

Parameter :: enum {
    Gain,
}

parameter_info := [len(Parameter)]clap.param_info_t{
    clap_param_info(.Gain, "Gain", 0, 1, 0.5, {.IS_AUTOMATABLE}),
}

plugin_init :: proc(plugin: ^Plugin) {
    window_init(&plugin.window, {{0, 0}, {400, 300}})
    plugin.window.child_kind = .Embedded
    plugin.window.plugin = plugin
    plugin.window.background_color = {0.2, 0.2, 0.2, 1}

    slider_init(&plugin.gain_slider)
    strings.builder_init(&plugin.test_text)
    editable_text_line_init(&plugin.test_text_line, &plugin.test_text)

    // plugin.box.size = {100, 50}
    // plugin.box_velocity = {10, 0}
}

plugin_destroy :: proc(plugin: ^Plugin) {}
plugin_reset :: proc(plugin: ^Plugin) {}

plugin_activate :: proc(plugin: ^Plugin, sample_rate: f64, min_frames, max_frames: int) {
    plugin.sample_rate = sample_rate
    plugin.min_frames = min_frames
    plugin.max_frames = max_frames
}

plugin_deactivate :: proc(plugin: ^Plugin) {}
plugin_start_processing :: proc(plugin: ^Plugin) {}
plugin_stop_processing :: proc(plugin: ^Plugin) {}

plugin_gui_init :: proc(plugin: ^Plugin) {
    plugin.gui_is_running = true
    plugin.gui_thread = thread.create_and_start_with_data(plugin, proc(data: rawptr) {
        plugin := cast(^Plugin)data
        gui_startup()
        defer gui_shutdown()
        for {
            if sync.atomic_load(&plugin.gui_is_running) {
                if !plugin.window.is_open && plugin.window.parent_handle != nil {
                    window_open(&plugin.window)
                }
            } else {
                window_close(&plugin.window)
            }
            gui_update(&plugin.window)
            poll_window_events()
            free_all(context.temp_allocator)
            if !plugin.gui_is_running && !plugin.window.is_open {
                break
            }
        }
        plugin.window.parent_handle = nil
    }, self_cleanup = true)
}

plugin_gui_destroy :: proc(plugin: ^Plugin) {
    sync.atomic_store(&plugin.gui_is_running, false)
}

plugin_gui_set_parent :: proc(plugin: ^Plugin, parent_handle: rawptr) {
    sync.atomic_store(&plugin.window.parent_handle, parent_handle)
}

plugin_gui_size :: proc(plugin: ^Plugin) -> (width, height: int) {
    width = int(sync.atomic_load(&plugin.window.size.x))
    height = int(sync.atomic_load(&plugin.window.size.y))
    return
}

plugin_gui_set_size :: proc(plugin: ^Plugin, width, height: int) {
    sync.atomic_store(&plugin.window.size.x, f32(width))
    sync.atomic_store(&plugin.window.size.y, f32(height))
}

plugin_gui_resize_hints :: proc(plugin: ^Plugin) -> Plugin_Gui_Resize_Hints {
    return {
        can_resize_horizontally = true,
        can_resize_vertically = true,
        preserve_aspect_ratio = false,
        aspect_ratio_width = 0,
        aspect_ratio_height = 0,
    }
}

plugin_gui_show :: proc(plugin: ^Plugin) {}
plugin_gui_hide :: proc(plugin: ^Plugin) {}

gui_update :: proc(window: ^Window) {
    window := cast(^Plugin_Window)window
    plugin := window.plugin
    if window_update(window) {
        gain := f32(parameter(plugin, .Gain))
        slider_update(&plugin.gain_slider, &gain, {{10, 10}, {200, 32}})
        set_parameter(plugin, .Gain, f64(gain))

        editable_text_line_update(&plugin.test_text_line, {{10, 100}, {100, 32}}, default_font)

        if mouse_pressed(.Right) {
            window_focus(window)
        }
        if mouse_pressed(.Middle) {
            window_native_focus(window.parent_handle)
        }

        if key_pressed(.A, respect_focus = false) {
            println("A Pressed")
        }
        if key_released(.A, respect_focus = false) {
            println("A Released")
        }
        if key_pressed(.B, respect_focus = true, repeat = true) {
            println("B Pressed")
        }
        if key_released(.B, respect_focus = true) {
            println("B Released")
        }
    }
}

// gui_update :: proc(user_data: rawptr) {
//     plugin := cast(^Plugin)user_data
//     if window_update(&plugin.window) {
//         if plugin.box.x < 0 {
//             plugin.box_velocity.x = 10
//         }
//         if plugin.box.x + plugin.box.size.x > plugin.window.size.x {
//             plugin.box_velocity.x = -10
//         }
//         plugin.box.position += plugin.box_velocity
//         fill_rounded_rectangle(plugin.box, 3, {1, 0, 0, 1})
//         if key_pressed(.A) {
//             println(cast(rawptr)plugin)
//         }
//     }
// }

milliseconds_to_samples :: proc "c" (plugin: ^Plugin, milliseconds: f64) -> int {
    return int(plugin.sample_rate * milliseconds * 0.001)
}