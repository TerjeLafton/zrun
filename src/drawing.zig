const std = @import("std");

const cairo = @import("cairo.zig");
const pango = @import("pango.zig");

pub fn drawWithCairo(allocator: std.mem.Allocator, width: i32, height: i32, app_names: []const []const u8, selected_index: usize, search_query: []const u8) ![]u8 {
    const size: usize = @intCast(width * height * 4);
    const buffer = try allocator.alloc(u8, size);

    const surface = cairo.Surface.createImageSurfaceForData(
        buffer.ptr,
        .argb32,
        width,
        height,
        width * 4,
    ) orelse return error.CairoSurfaceCreateFailed;
    defer surface.destroy();

    const cr = cairo.Context.create(surface) orelse return error.CairoContextCreateFailed;
    defer cr.destroy();

    cr.setOperator(.source);
    cr.setSourceRgba(0, 0, 0, 0.5);
    cr.rectangle(0, 0, @floatFromInt(width), @floatFromInt(height));
    cr.fill();
    cr.setOperator(.over);

    const center_x: f64 = @as(f64, @floatFromInt(width)) / 2.0;
    const center_y: f64 = @as(f64, @floatFromInt(height)) / 2.0;

    const layout = pango.Layout.create(cr) orelse return error.PangoLayoutCreateFailed;
    defer layout.destroy();

    const font_desc = pango.FontDescription.fromString("Berkeley Mono 20") orelse return error.PangoFontDescriptionFailed;
    defer font_desc.free();

    layout.setFontDescription(font_desc);

    const search_y = center_y - 200;
    var search_buf: [256]u8 = undefined;
    const search_text = if (search_query.len > 0)
        std.fmt.bufPrintZ(&search_buf, "> {s}", .{search_query}) catch unreachable
    else
        std.fmt.bufPrintZ(&search_buf, "> ", .{}) catch unreachable;
    layout.setText(search_text.ptr, -1);

    cr.setSourceRgb(205.0 / 255.0, 214.0 / 255.0, 244.0 / 255.0);
    cr.moveTo(center_x - 200, search_y);
    pango.showLayout(cr, layout);

    const line_height: f64 = 50;
    const list_start_y = search_y + 80;

    const display_count = @min(app_names.len, 10);
    for (app_names[0..display_count], 0..) |app_name, i| {
        const y_pos = list_start_y + @as(f64, @floatFromInt(i)) * line_height;

        var buf: [256]u8 = undefined;
        const text = std.fmt.bufPrintZ(&buf, "{s}", .{app_name}) catch continue;

        layout.setText(text.ptr, -1);

        if (i == selected_index) {
            cr.setSourceRgb(250.0 / 255.0, 179.0 / 255.0, 135.0 / 255.0);
        } else {
            cr.setSourceRgb(205.0 / 255.0, 214.0 / 255.0, 244.0 / 255.0);
        }

        cr.moveTo(center_x - 200, y_pos);
        pango.showLayout(cr, layout);
    }

    return buffer;
}

pub fn createCheckerboard(allocator: std.mem.Allocator, width: i32, height: i32) ![]u8 {
    const size: usize = @intCast(width * height * 4);
    const buffer = try allocator.alloc(u8, size);
    const pixels: [*]u32 = @ptrCast(@alignCast(buffer.ptr));

    for (0..@intCast(height)) |y| {
        for (0..@intCast(width)) |x| {
            const color: u32 = if ((x + y / 8 * 8) % 16 < 8)
                0xFF666666
            else
                0xFFEEEEEE;
            pixels[y * @as(usize, @intCast(width)) + x] = color;
        }
    }

    return buffer;
}
