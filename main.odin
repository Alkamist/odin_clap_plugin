package main

import "core:sync"
import "core:thread"
import "core:strings"
import "clap"
import gl "vendor:OpenGL"

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

    gui_is_running: bool,
    gui_thread: ^thread.Thread,
    parent_handle: rawptr,
    window_width: int,
    window_height: int,

    sample_rate: f64,
    min_frames: int,
    max_frames: int,
}

Parameter_Id :: enum {
    Gain,
}

parameter_info := [len(Parameter_Id)]clap.param_info_t{
    clap_param_info(.Gain, "Gain", 0, 1, 0.5, {.IS_AUTOMATABLE}),
}

startup :: proc() {}
shutdown :: proc() {}

plugin_init :: proc(plugin: ^Plugin) {
    plugin.window_width = 400
    plugin.window_height = 300
}
plugin_destroy :: proc(plugin: ^Plugin) {}
plugin_reset :: proc(plugin: ^Plugin) {}

plugin_activate :: proc(plugin: ^Plugin, sample_rate: f64, min_frames, max_frames: int) {
    sync.atomic_store(&plugin.sample_rate, sample_rate)
    sync.atomic_store(&plugin.min_frames, min_frames)
    sync.atomic_store(&plugin.max_frames, max_frames)
}

plugin_deactivate :: proc(plugin: ^Plugin) {}
plugin_start_processing :: proc(plugin: ^Plugin) {}
plugin_stop_processing :: proc(plugin: ^Plugin) {}

plugin_timer :: proc(plugin: ^Plugin) {}

plugin_gui_init :: proc(plugin: ^Plugin) {}

plugin_gui_destroy :: proc(plugin: ^Plugin) {
    sync.atomic_store(&plugin.gui_is_running, false)
    thread.join(plugin.gui_thread)
    thread.destroy(plugin.gui_thread)
    plugin.gui_thread = nil
}

plugin_gui_set_parent :: proc(plugin: ^Plugin, parent_handle: rawptr) {
    sync.atomic_store(&plugin.gui_is_running, true)
    sync.atomic_store(&plugin.parent_handle, parent_handle)
    plugin.gui_thread = thread.create_and_start_with_data(plugin, proc(data: rawptr) {
        plugin := cast(^Plugin)data

        window_width := sync.atomic_load(&plugin.window_width)
        window_height := sync.atomic_load(&plugin.window_height)

        window: Plugin_Window
        window_init(&window, {{0, 0}, {f32(window_width), f32(window_height)}})
        window.open_requested = true
        window.parent_handle = plugin.parent_handle
        defer window_destroy(&window)

        gain_slider: Parameter_Slider
        parameter_slider_init(&gain_slider)

        test_text: strings.Builder
        strings.builder_init(&test_text)
        defer strings.builder_destroy(&test_text)

        test_text_line: Editable_Text_Line
        editable_text_line_init(&test_text_line, &test_text)
        defer editable_text_line_destroy(&test_text_line)

        box := Rectangle{{0, 0}, {100, 50}}
        box_velocity := Vector2{1500, 0}

        for sync.atomic_load(&plugin.gui_is_running) {
            window_width = sync.atomic_load(&plugin.window_width)
            window_height = sync.atomic_load(&plugin.window_height)
            window.size = {f32(window_width), f32(window_height)}

            if window_update(&window) {
                clear_background({0.2, 0.2, 0.2, 1})

                if box.x < 0 {
                    box_velocity.x = 1500
                }
                if box.x + box.size.x > window.size.x {
                    box_velocity.x = -1500
                }
                box.position += box_velocity * delta_time()
                fill_rounded_rectangle(box, 3, {1, 0, 0, 1})

                parameter_slider_update(&gain_slider, plugin, .Gain, {{10, 10}, {200, 32}})
                editable_text_line_update(&test_text_line, {{10, 100}, {100, 32}}, default_font)

                if mouse_pressed(.Right) {
                    set_window_focus(&window)
                }
                if mouse_pressed(.Middle) {
                    set_window_focus_native(window.parent_handle)
                }

                // if key_pressed(.Left_Shift, respect_focus = false) {
                //     println("Pressed")
                // }
                // if key_released(.Left_Shift, respect_focus = false) {
                //     println("Released")
                // }

                // sync.atomic_store(&plugin.window_width, int(window.size.x))
                // sync.atomic_store(&plugin.window_height, int(window.size.y))
            }

            poll_window_events()
            free_all(context.temp_allocator)
        }

        // println("Done")
    })
}

// gui_update :: proc(window: ^Window) {
//     window := cast(^Plugin_Window)window
//     plugin := window.plugin
//     if window_update(window) {
//         if window.box.x < 0 {
//             window.box_velocity.x = 1500
//         }
//         if window.box.x + window.box.size.x > window.window.size.x {
//             window.box_velocity.x = -1500
//         }
//         window.box.position += window.box_velocity * delta_time()
//         fill_rounded_rectangle(window.box, 3, {1, 0, 0, 1})

//         parameter_slider_update(&window.gain_slider, plugin, .Gain, {{10, 10}, {200, 32}})
//         editable_text_line_update(&window.test_text_line, {{10, 100}, {100, 32}}, default_font)

//         // if mouse_pressed(.Right) {
//         //     window_focus(window)
//         // }
//         // if mouse_pressed(.Middle) {
//         //     window_native_focus(window.parent_handle)
//         // }

//         // if key_pressed(.A, respect_focus = false, repeat = true) {
//         //     println("A Pressed")
//         // }
//         // if key_released(.A, respect_focus = false) {
//         //     println("A Released")
//         // }
//         // if key_pressed(.B, respect_focus = true, repeat = true) {
//         //     println("B Pressed")
//         // }
//         // if key_released(.B, respect_focus = true) {
//         //     println("B Released")
//         // }
//     }
// }

plugin_gui_size :: proc(plugin: ^Plugin) -> (width, height: int) {
    width = sync.atomic_load(&plugin.window_width)
    height = sync.atomic_load(&plugin.window_height)
    return
}

plugin_gui_set_size :: proc(plugin: ^Plugin, width, height: int) {
    sync.atomic_store(&plugin.window_width, width)
    sync.atomic_store(&plugin.window_height, height)
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

milliseconds_to_samples :: proc "c" (plugin: ^Plugin, milliseconds: f64) -> int {
    return int(plugin.sample_rate * milliseconds * 0.001)
}

Parameter_Slider :: struct {
    id: Id,
    held: bool,
    value_when_grabbed: f64,
    global_mouse_position_when_grabbed: Vector2,
}

parameter_slider_init :: proc(slider: ^Parameter_Slider) {
    slider.id = get_id()
}

parameter_slider_update :: proc(
    slider: ^Parameter_Slider,
    plugin: ^Plugin,
    parameter_id: Parameter_Id,
    rectangle: Rectangle,
) {
    HANDLE_LENGTH :: 16

    if mouse_hit_test(rectangle) {
        request_mouse_hover(slider.id)
    }

    reset_grab_info := false

    MOUSE_BUTTON :: Mouse_Button.Left
    PRECISION_KEY :: Keyboard_Key.Left_Shift

    min_value := parameter_info[parameter_id].min_value
    max_value := parameter_info[parameter_id].max_value

    if slider.held {
        if key_pressed(PRECISION_KEY) || key_released(PRECISION_KEY) {
            reset_grab_info = true
        }
    }

    if !slider.held && mouse_hover() == slider.id && mouse_pressed(MOUSE_BUTTON) {
        slider.held = true
        reset_grab_info = true
        capture_mouse_hover()
        begin_parameter_change(plugin, parameter_id)
    }

    value := parameter_value(plugin, parameter_id)

    if reset_grab_info {
        slider.value_when_grabbed = value
        slider.global_mouse_position_when_grabbed = global_mouse_position()
    }

    if slider.held {
        sensitivity: f64 = key_down(PRECISION_KEY) ? 0.15 : 1.0
        global_mouse_position := global_mouse_position()
        grab_delta := f64(global_mouse_position.x - slider.global_mouse_position_when_grabbed.x)
        value = slider.value_when_grabbed + sensitivity * grab_delta * (max_value - min_value) / f64(rectangle.size.x - HANDLE_LENGTH)

        if mouse_released(MOUSE_BUTTON) {
            slider.held = false
            release_mouse_hover()
            end_parameter_change(plugin, parameter_id)
        }
    }

    value = clamp(value, min_value, max_value)

    set_parameter_value(plugin, parameter_id, value)

    slider_path := temp_path()
    path_rectangle(&slider_path, rectangle)

    fill_path(slider_path, {0.05, 0.05, 0.05, 1})

    handle_rectangle := Rectangle{
        rectangle.position + {
            (rectangle.size.x - HANDLE_LENGTH) * f32(value - min_value) / f32(max_value - min_value),
            0,
        }, {
            HANDLE_LENGTH,
            rectangle.size.y,
        },
    }
    handle_path := temp_path()
    path_rectangle(&handle_path, handle_rectangle)

    fill_path(handle_path, {0.4, 0.4, 0.4, 1})
    if slider.held {
        fill_path(handle_path, {0, 0, 0, 0.2})
    } else if mouse_hover() == slider.id {
        fill_path(handle_path, {1, 1, 1, 0.05})
    }
}