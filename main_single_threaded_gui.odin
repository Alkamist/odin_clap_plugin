package main

// import "core:sync"
// import "core:strings"

// default_font := Font{
//     name = "consola_13",
//     size = 13,
//     data = #load("consola.ttf"),
// }

// milliseconds_to_samples :: proc "c" (plugin: ^Plugin, milliseconds: f64) -> int {
//     return int(plugin.sample_rate * milliseconds * 0.001)
// }

// //==========================================================================
// // Plugin
// //==========================================================================

// Plugin :: struct {
//     using base: Plugin_Base,
//     window: Plugin_Window,
//     sample_rate: f64,
//     min_frames: int,
//     max_frames: int,
// }

// startup :: proc() {}
// shutdown :: proc() {}

// plugin_init :: proc(plugin: ^Plugin) {
//     plugin_window_init(&plugin.window)
// }

// plugin_destroy :: proc(plugin: ^Plugin) {
//     plugin_window_destroy(&plugin.window)
// }

// plugin_reset :: proc(plugin: ^Plugin) {}

// plugin_activate :: proc(plugin: ^Plugin, sample_rate: f64, min_frames, max_frames: int) {
//     sync.atomic_store(&plugin.sample_rate, sample_rate)
//     sync.atomic_store(&plugin.min_frames, min_frames)
//     sync.atomic_store(&plugin.max_frames, max_frames)
// }

// plugin_deactivate :: proc(plugin: ^Plugin) {}
// plugin_start_processing :: proc(plugin: ^Plugin) {}
// plugin_stop_processing :: proc(plugin: ^Plugin) {}

// plugin_timer :: proc(plugin: ^Plugin) {
//     plugin_window_update(&plugin.window)
// }

// //==========================================================================
// // State
// //==========================================================================

// Plugin_State :: struct {
//     size: i64le,
//     version: i64le,
//     parameter_offset: i64le,
//     parameter_count: i64le,
//     parameter_values: [Parameter_Id]f64le,
// }

// plugin_save_state :: proc(plugin: ^Plugin, builder: ^strings.Builder) {
//     state := Plugin_State{
//         size = size_of(Plugin_State),
//         version = 1,
//         parameter_offset = i64le(offset_of(Plugin_State, parameter_values)),
//         parameter_count = len(Parameter_Id),
//     }
//     for id in Parameter_Id {
//         state.parameter_values[id] = f64le(parameter_value(plugin, id))
//     }
//     preset_data := transmute([size_of(state)]byte)state
//     strings.write_bytes(builder, preset_data[:])
// }

// plugin_load_state :: proc(plugin: ^Plugin, data: []byte) {
//     state := (cast(^Plugin_State)&data[0])^
//     for id in Parameter_Id {
//         set_parameter_value(plugin, id, f64(state.parameter_values[id]))
//     }
// }

// //==========================================================================
// // Gui
// //==========================================================================

// gui_event :: proc(window: ^Window, event: Gui_Event) {
//     window := cast(^Plugin_Window)window
//     #partial switch event in event {
//     case Gui_Event_Mouse_Move: plugin_window_update(window)
//     case Gui_Event_Mouse_Press: plugin_window_update(window)
//     case Gui_Event_Mouse_Release: plugin_window_update(window)
//     case Gui_Event_Mouse_Scroll: plugin_window_update(window)
//     case Gui_Event_Key_Press: plugin_window_update(window)
//     case Gui_Event_Key_Release: plugin_window_update(window)
//     case Gui_Event_Rune_Input: plugin_window_update(window)
//     }
// }

// Plugin_Window :: struct {
//     using window: Window,
//     plugin: ^Plugin,
//     gain_slider: Parameter_Slider,
//     test_text: strings.Builder,
//     test_text_line: Editable_Text_Line,
//     box: Rectangle,
//     box_velocity: Vector2,
// }

// plugin_window_init :: proc(window: ^Plugin_Window) {
//     window_init(window, {{0, 0}, {400, 300}})
//     window.child_kind = .Embedded

//     parameter_slider_init(&window.gain_slider)
//     strings.builder_init(&window.test_text)
//     editable_text_line_init(&window.test_text_line, &window.test_text)

//     window.box = {{0, 0}, {100, 50}}
//     window.box_velocity = {1500, 0}
// }

// plugin_window_destroy :: proc(window: ^Plugin_Window) {
//     editable_text_line_destroy(&window.test_text_line)
//     strings.builder_destroy(&window.test_text)
//     window_destroy(window)
// }

// plugin_window_update :: proc(window: ^Plugin_Window) {
//     if window_update(window) {
//         clear_background({0.2, 0.2, 0.2, 1})

//         if window.box.x < 0 {
//             window.box_velocity.x = 1500
//         }
//         if window.box.x + window.box.size.x > window.size.x {
//             window.box_velocity.x = -1500
//         }
//         window.box.position += window.box_velocity * delta_time()
//         fill_rounded_rectangle(window.box, 3, {1, 0, 0, 1})

//         parameter_slider_update(&window.gain_slider, window.plugin, .Gain, {{10, 10}, {200, 32}})
//         editable_text_line_update(&window.test_text_line, {{10, 100}, {100, 32}}, default_font)

//         if mouse_pressed(.Right) {
//             set_window_focus(window)
//         }
//         if mouse_pressed(.Middle) {
//             set_window_focus_native(window.parent_handle)
//         }
//     }
// }

// plugin_gui_init :: proc(plugin: ^Plugin, width, height: int, parent_handle: rawptr) {
//     plugin.window.plugin = plugin
//     plugin.window.parent_handle = parent_handle
//     plugin.window.size.x = f32(width)
//     plugin.window.size.y = f32(height)
//     window_open(&plugin.window)
// }

// plugin_gui_destroy :: proc(plugin: ^Plugin) {
//     window_close(&plugin.window)
// }

// plugin_gui_size :: proc(plugin: ^Plugin) -> (width, height: int) {
//     width = int(plugin.window.size.x)
//     height = int(plugin.window.size.y)
//     return
// }

// plugin_gui_set_size :: proc(plugin: ^Plugin, width, height: int) {
//     plugin.window.size.x = f32(width)
//     plugin.window.size.y = f32(height)
// }

// plugin_gui_resize_hints :: proc(plugin: ^Plugin) -> Plugin_Gui_Resize_Hints {
//     return {
//         can_resize_horizontally = true,
//         can_resize_vertically = true,
//         preserve_aspect_ratio = false,
//         aspect_ratio_width = 1,
//         aspect_ratio_height = 1,
//     }
// }

// plugin_gui_show :: proc(plugin: ^Plugin) {}
// plugin_gui_hide :: proc(plugin: ^Plugin) {}

// //==========================================================================
// // Parameters
// //==========================================================================

// Parameter_Id :: enum {
//     Gain,
// }

// parameter_info := [?]Parameter_Info{
//     {.Gain, "Gain", 0, 1, 0.5, {.Is_Automatable}, ""},
// }

// Parameter_Slider :: struct {
//     id: Id,
//     held: bool,
//     value_when_grabbed: f64,
//     global_mouse_position_when_grabbed: Vector2,
// }

// parameter_slider_init :: proc(slider: ^Parameter_Slider) {
//     slider.id = get_id()
// }

// parameter_slider_update :: proc(
//     slider: ^Parameter_Slider,
//     plugin: ^Plugin,
//     parameter_id: Parameter_Id,
//     rectangle: Rectangle,
// ) {
//     HANDLE_LENGTH :: 16

//     if mouse_hit_test(rectangle) {
//         request_mouse_hover(slider.id)
//     }

//     reset_grab_info := false

//     MOUSE_BUTTON :: Mouse_Button.Left
//     PRECISION_KEY :: Keyboard_Key.Left_Shift

//     min_value := parameter_info[parameter_id].min_value
//     max_value := parameter_info[parameter_id].max_value

//     if slider.held {
//         if key_pressed(PRECISION_KEY) || key_released(PRECISION_KEY) {
//             reset_grab_info = true
//         }
//     }

//     if !slider.held && mouse_hover() == slider.id && mouse_pressed(MOUSE_BUTTON) {
//         slider.held = true
//         reset_grab_info = true
//         capture_mouse_hover()
//         begin_parameter_change(plugin, parameter_id)
//     }

//     value := parameter_value(plugin, parameter_id)

//     if reset_grab_info {
//         slider.value_when_grabbed = value
//         slider.global_mouse_position_when_grabbed = global_mouse_position()
//     }

//     if slider.held {
//         sensitivity: f64 = key_down(PRECISION_KEY) ? 0.15 : 1.0
//         global_mouse_position := global_mouse_position()
//         grab_delta := f64(global_mouse_position.x - slider.global_mouse_position_when_grabbed.x)
//         value = slider.value_when_grabbed + sensitivity * grab_delta * (max_value - min_value) / f64(rectangle.size.x - HANDLE_LENGTH)

//         if mouse_released(MOUSE_BUTTON) {
//             slider.held = false
//             release_mouse_hover()
//             end_parameter_change(plugin, parameter_id)
//         }
//     }

//     value = clamp(value, min_value, max_value)

//     set_parameter_value(plugin, parameter_id, value)

//     slider_path := temp_path()
//     path_rectangle(&slider_path, rectangle)

//     fill_path(slider_path, {0.05, 0.05, 0.05, 1})

//     handle_rectangle := Rectangle{
//         rectangle.position + {
//             (rectangle.size.x - HANDLE_LENGTH) * f32(value - min_value) / f32(max_value - min_value),
//             0,
//         }, {
//             HANDLE_LENGTH,
//             rectangle.size.y,
//         },
//     }
//     handle_path := temp_path()
//     path_rectangle(&handle_path, handle_rectangle)

//     fill_path(handle_path, {0.4, 0.4, 0.4, 1})
//     if slider.held {
//         fill_path(handle_path, {0, 0, 0, 0.2})
//     } else if mouse_hover() == slider.id {
//         fill_path(handle_path, {1, 1, 1, 0.05})
//     }
// }