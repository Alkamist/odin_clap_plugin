package main

import "core:sync"
import "core:thread"
import "core:strings"
import "clap"

// Send parameter gestures to clap
// Fix crash when deactivating plugin
// State saving

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

    gain_slider: Parameter_Slider,
    test_text: strings.Builder,
    test_text_line: Editable_Text_Line,

    box: Rectangle,
    box_velocity: Vector2,
}

Parameter_Id :: enum {
    Gain,
}

parameter_info := [len(Parameter_Id)]clap.param_info_t{
    clap_param_info(.Gain, "Gain", 0, 1, 0.5, {.IS_AUTOMATABLE}),
}

plugin_init :: proc(plugin: ^Plugin) {
    window_init(&plugin.window, {{0, 0}, {400, 300}})
    plugin.window.child_kind = .Embedded
    plugin.window.plugin = plugin
    plugin.window.background_color = {0.2, 0.2, 0.2, 1}

    parameter_slider_init(&plugin.gain_slider)
    strings.builder_init(&plugin.test_text)
    editable_text_line_init(&plugin.test_text_line, &plugin.test_text)

    plugin.box.position.y = 150
    plugin.box.size = {100, 50}
    plugin.box_velocity = {1500, 0}
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
            poll_window_events(1.0 / 240.0)
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
        if plugin.box.x < 0 {
            plugin.box_velocity.x = 1500
        }
        if plugin.box.x + plugin.box.size.x > plugin.window.size.x {
            plugin.box_velocity.x = -1500
        }
        plugin.box.position += plugin.box_velocity * delta_time()
        fill_rounded_rectangle(plugin.box, 3, {1, 0, 0, 1})

        parameter_slider_update(&plugin.gain_slider, plugin, .Gain, {{10, 10}, {200, 32}})
        editable_text_line_update(&plugin.test_text_line, {{10, 100}, {100, 32}}, default_font)

        // if mouse_pressed(.Right) {
        //     window_focus(window)
        // }
        // if mouse_pressed(.Middle) {
        //     window_native_focus(window.parent_handle)
        // }

        // if key_pressed(.A, respect_focus = false, repeat = true) {
        //     println("A Pressed")
        // }
        // if key_released(.A, respect_focus = false) {
        //     println("A Released")
        // }
        // if key_pressed(.B, respect_focus = true, repeat = true) {
        //     println("B Pressed")
        // }
        // if key_released(.B, respect_focus = true) {
        //     println("B Released")
        // }
    }
}

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
        if key_pressed(PRECISION_KEY, respect_focus = false) ||
           key_released(PRECISION_KEY, respect_focus = false) {
            reset_grab_info = true
        }
    }

    if !slider.held && mouse_hover() == slider.id && mouse_pressed(MOUSE_BUTTON) {
        slider.held = true
        reset_grab_info = true
        capture_mouse_hover()
        begin_parameter_change(plugin, parameter_id)
    }

    value := sync.atomic_load(&plugin.parameters[parameter_id].value)

    if reset_grab_info {
        slider.value_when_grabbed = value
        slider.global_mouse_position_when_grabbed = global_mouse_position()
    }

    if slider.held {
        sensitivity: f64 = key_down(PRECISION_KEY, respect_focus = false) ? 0.15 : 1.0
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