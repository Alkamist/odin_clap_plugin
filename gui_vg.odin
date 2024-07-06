package main

import "core:fmt"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"

Vg_Context :: struct {
    nvg_ctx: ^nvg.Context,
}

vg_init :: proc(ctx: ^Vg_Context) {
    ctx.nvg_ctx = nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES})
}

vg_destroy :: proc(ctx: ^Vg_Context) {
    nvg_gl.Destroy(ctx.nvg_ctx)
    ctx.nvg_ctx = nil
}

vg_begin_frame :: proc(ctx: ^Vg_Context, size: Vector2, content_scale: f32) {
    nvg.BeginFrame(ctx.nvg_ctx, size.x, size.y, content_scale)
}

vg_end_frame :: proc(ctx: ^Vg_Context) {
    nvg.EndFrame(ctx.nvg_ctx)
}

vg_load_font :: proc(ctx: ^Vg_Context, font: Font) {
    if len(font.data) <= 0 do return
    if nvg.CreateFontMem(ctx.nvg_ctx, font.name, font.data, false) == -1 {
        fmt.eprintf("Failed to load font: %v\n", font.name)
    }
}

vg_measure_glyphs :: proc(ctx: ^Vg_Context, str: string, font: Font, glyphs: ^[dynamic]Text_Glyph) {
    nvg_ctx := ctx.nvg_ctx

    clear(glyphs)

    if len(str) == 0 {
        return
    }

    nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))

    nvg_positions := make([dynamic]nvg.Glyph_Position, len(str), context.temp_allocator)

    temp_slice := nvg_positions[:]
    position_count := nvg.TextGlyphPositions(nvg_ctx, 0, 0, str, &temp_slice)

    resize(glyphs, position_count)

    for i in 0 ..< position_count {
        glyphs[i] = Text_Glyph{
            byte_index = nvg_positions[i].str,
            position = nvg_positions[i].x,
            width = nvg_positions[i].maxx - nvg_positions[i].minx,
            kerning = (nvg_positions[i].x - nvg_positions[i].minx),
        }
    }
}

vg_font_metrics :: proc(ctx: ^Vg_Context, font: Font) -> (metrics: Font_Metrics) {
    nvg_ctx := ctx.nvg_ctx
    nvg.FontFace(nvg_ctx, font.name)
    nvg.FontSize(nvg_ctx, f32(font.size))
    metrics.ascender, metrics.descender, metrics.line_height = nvg.TextMetrics(nvg_ctx)
    return
}

vg_render_draw_command :: proc(ctx: ^Vg_Context, command: Draw_Command) {
    nvg_ctx := ctx.nvg_ctx

    switch cmd in command {
    case Fill_Path_Command:
        nvg.Save(nvg_ctx)

        nvg.Translate(nvg_ctx, cmd.position.x, cmd.position.y)
        nvg.BeginPath(nvg_ctx)

        for sub_path in cmd.path.sub_paths {
            nvg.MoveTo(nvg_ctx, sub_path.points[0].x, sub_path.points[0].y)

            for i := 1; i < len(sub_path.points); i += 3 {
                c1 := sub_path.points[i]
                c2 := sub_path.points[i + 1]
                point := sub_path.points[i + 2]
                nvg.BezierTo(nvg_ctx,
                    c1.x, c1.y,
                    c2.x, c2.y,
                    point.x, point.y,
                )
            }

            if sub_path.is_closed {
                nvg.ClosePath(nvg_ctx)
                if sub_path.is_hole {
                    nvg.PathWinding(nvg_ctx, .CW)
                }
            }
        }

        nvg.FillColor(nvg_ctx, cmd.color)
        nvg.Fill(nvg_ctx)

        nvg.Restore(nvg_ctx)

    case Fill_String_Command:
        nvg.Save(nvg_ctx)
        position := pixel_snapped(cmd.position)
        nvg.TextAlign(nvg_ctx, .LEFT, .TOP)
        nvg.FontFace(nvg_ctx, cmd.font.name)
        nvg.FontSize(nvg_ctx, f32(cmd.font.size))
        nvg.FillColor(nvg_ctx, cmd.color)
        nvg.Text(nvg_ctx, position.x, position.y, cmd.text)
        nvg.Restore(nvg_ctx)

    case Set_Clip_Rectangle_Command:
        rect := pixel_snapped(cmd.global_clip_rectangle)
        nvg.Scissor(nvg_ctx, rect.position.x, rect.position.y, max(0, rect.size.x), max(0, rect.size.y))

    case Box_Shadow_Command:
        nvg.Save(nvg_ctx)
        rect := cmd.rectangle
        paint := nvg.BoxGradient(
            rect.x, rect.y,
            rect.size.x, rect.size.y,
            cmd.corner_radius,
            cmd.feather,
            cmd.inner_color,
            cmd.outer_color,
        )
        nvg.BeginPath(nvg_ctx)
        nvg.Rect(nvg_ctx,
            rect.x - cmd.feather, rect.y - cmd.feather,
            rect.size.x + cmd.feather * 2, rect.size.y + cmd.feather * 2,
        )
        nvg.FillPaint(nvg_ctx, paint)
        nvg.Fill(nvg_ctx)
        nvg.Restore(nvg_ctx)
    }
}