package main

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
    sample_rate: f64,
    min_frames: int,
    max_frames: int,
    // box: Rectangle,
    // box_velocity: Vector2,
    gain_slider: Slider,
    test_text: strings.Builder,
    test_text_line: Editable_Text_Line,
}

Parameter :: enum {
    Gain,
}

parameter_info := [len(Parameter)]clap.param_info_t{
    clap_param_info(.Gain, "Gain", 0, 1, 0.5, {.IS_AUTOMATABLE}),
}

plugin_init :: proc(plugin: ^Plugin) {
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

gui_update :: proc(window: ^Window) {
    window := cast(^Plugin_Window)window
    plugin := window.plugin
    if window_update(window) {
        gain := f32(parameter(plugin, .Gain))
        slider_update(&plugin.gain_slider, &gain, {{10, 10}, {200, 32}})
        set_parameter(plugin, .Gain, f64(gain))

        editable_text_line_update(&plugin.test_text_line, {{10, 100}, {100, 32}}, default_font)

        // if mouse_pressed(.Left) {
        //     println(window.is_focused)
        // }

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