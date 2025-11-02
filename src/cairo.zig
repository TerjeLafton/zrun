const cairo = @cImport({
    @cInclude("cairo/cairo.h");
});

pub const Surface = opaque {
    pub fn createImageSurfaceForData(
        data: [*]u8,
        format: Format,
        width: i32,
        height: i32,
        stride: i32,
    ) ?*Surface {
        return @ptrCast(cairo.cairo_image_surface_create_for_data(
            data,
            @intFromEnum(format),
            width,
            height,
            stride,
        ));
    }

    pub fn destroy(self: *Surface) void {
        cairo.cairo_surface_destroy(@ptrCast(self));
    }
};

pub const Context = opaque {
    pub fn create(surface: *Surface) ?*Context {
        return @ptrCast(cairo.cairo_create(@ptrCast(surface)));
    }

    pub fn destroy(self: *Context) void {
        cairo.cairo_destroy(@ptrCast(self));
    }

    pub fn setSourceRgb(self: *Context, r: f64, g: f64, b: f64) void {
        cairo.cairo_set_source_rgb(@ptrCast(self), r, g, b);
    }

    pub fn setSourceRgba(self: *Context, r: f64, g: f64, b: f64, a: f64) void {
        cairo.cairo_set_source_rgba(@ptrCast(self), r, g, b, a);
    }

    pub fn setOperator(self: *Context, op: Operator) void {
        cairo.cairo_set_operator(@ptrCast(self), @intFromEnum(op));
    }

    pub fn rectangle(self: *Context, x: f64, y: f64, width: f64, height: f64) void {
        cairo.cairo_rectangle(@ptrCast(self), x, y, width, height);
    }

    pub fn fill(self: *Context) void {
        cairo.cairo_fill(@ptrCast(self));
    }

    pub fn fillPreserve(self: *Context) void {
        cairo.cairo_fill_preserve(@ptrCast(self));
    }

    pub fn stroke(self: *Context) void {
        cairo.cairo_stroke(@ptrCast(self));
    }

    pub fn setLineWidth(self: *Context, width: f64) void {
        cairo.cairo_set_line_width(@ptrCast(self), width);
    }

    pub fn newPath(self: *Context) void {
        cairo.cairo_new_path(@ptrCast(self));
    }

    pub fn moveTo(self: *Context, x: f64, y: f64) void {
        cairo.cairo_move_to(@ptrCast(self), x, y);
    }

    pub fn lineTo(self: *Context, x: f64, y: f64) void {
        cairo.cairo_line_to(@ptrCast(self), x, y);
    }

    pub fn arc(self: *Context, xc: f64, yc: f64, radius: f64, angle1: f64, angle2: f64) void {
        cairo.cairo_arc(@ptrCast(self), xc, yc, radius, angle1, angle2);
    }

    pub fn closePath(self: *Context) void {
        cairo.cairo_close_path(@ptrCast(self));
    }
};

pub const Format = enum(c_int) {
    argb32 = 0,
    rgb24 = 1,
    a8 = 2,
    a1 = 3,
};

pub const Operator = enum(c_uint) {
    clear = 0,
    source = 1,
    over = 2,
};

const std = @import("std");
const pi = std.math.pi;

pub fn roundedRectangle(cr: *Context, x: f64, y: f64, width: f64, height: f64, radius: f64) void {
    const degrees = pi / 180.0;

    cr.newPath();
    cr.arc(x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees);
    cr.arc(x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees);
    cr.arc(x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees);
    cr.arc(x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
    cr.closePath();
}
