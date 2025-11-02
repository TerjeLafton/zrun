const pango = @cImport({
    @cInclude("pango/pangocairo.h");
});

const cairo = @import("cairo.zig");

pub const Layout = opaque {
    pub fn create(cr: *cairo.Context) ?*Layout {
        return @ptrCast(pango.pango_cairo_create_layout(@ptrCast(cr)));
    }

    pub fn setText(self: *Layout, text: [*:0]const u8, length: i32) void {
        pango.pango_layout_set_text(@ptrCast(self), text, length);
    }

    pub fn setFontDescription(self: *Layout, desc: *FontDescription) void {
        pango.pango_layout_set_font_description(@ptrCast(self), @ptrCast(desc));
    }

    pub fn destroy(self: *Layout) void {
        pango.g_object_unref(@ptrCast(self));
    }
};

pub const FontDescription = opaque {
    pub fn fromString(str: [*:0]const u8) ?*FontDescription {
        return @ptrCast(pango.pango_font_description_from_string(str));
    }

    pub fn free(self: *FontDescription) void {
        pango.pango_font_description_free(@ptrCast(self));
    }
};

pub fn showLayout(cr: *cairo.Context, layout: *Layout) void {
    pango.pango_cairo_show_layout(@ptrCast(cr), @ptrCast(layout));
}

pub fn updateLayout(cr: *cairo.Context, layout: *Layout) void {
    pango.pango_cairo_update_layout(@ptrCast(cr), @ptrCast(layout));
}
