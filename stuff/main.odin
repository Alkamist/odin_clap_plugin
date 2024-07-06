package main

import "core:sync"
import "core:thread"
import "core:strings"
import "clap"
import gl "vendor:OpenGL"
import "oswindow"

Plugin_Window :: struct {
    using window: oswindow.Window,
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

// plugin_gui_set_parent :: proc(plugin: ^Plugin, parent_handle: rawptr) {
//     sync.atomic_store(&plugin.gui_is_running, true)
//     sync.atomic_store(&plugin.parent_handle, parent_handle)
//     plugin.gui_thread = thread.create_and_start_with_data(plugin, proc(data: rawptr) {
//         plugin := cast(^Plugin)data

//         window: Plugin_Window
//         oswindow.open(&window, "", 0, 0, 400, 300, plugin.parent_handle)
//         oswindow.show(&window)
//         defer oswindow.close(&window)

//         for sync.atomic_load(&plugin.gui_is_running) {
//             oswindow.poll_events()
//             gl.Viewport(0, 0, 400, 300)
//             gl.ClearColor(1, 0, 0, 1)
//             gl.Clear(gl.COLOR_BUFFER_BIT)
//             oswindow.swap_buffers(&window)
//             free_all(context.temp_allocator)
//         }

//         // println("Done")
//     })
// }

plugin_gui_set_parent :: proc(plugin: ^Plugin, parent_handle: rawptr) {
    sync.atomic_store(&plugin.gui_is_running, true)
    sync.atomic_store(&plugin.parent_handle, parent_handle)
    plugin.gui_thread = thread.create_and_start_with_data(plugin, proc(data: rawptr) {
        plugin := cast(^Plugin)data

        window: Plugin_Window
        oswindow.open(&window, "", 0, 0, 400, 300, plugin.parent_handle)
        oswindow.show(&window)
        defer oswindow.close(&window)

        for sync.atomic_load(&plugin.gui_is_running) {
            oswindow.poll_events()
            gl.Viewport(0, 0, 400, 300)
            gl.ClearColor(1, 0, 0, 1)
            gl.Clear(gl.COLOR_BUFFER_BIT)
            oswindow.swap_buffers(&window)
            free_all(context.temp_allocator)
        }

        // println("Done")
    })
}

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