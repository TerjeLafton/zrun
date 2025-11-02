const xkb = @cImport({
    @cInclude("xkbcommon/xkbcommon.h");
});

pub const Context = opaque {
    pub fn new() ?*Context {
        return @ptrCast(xkb.xkb_context_new(xkb.XKB_CONTEXT_NO_FLAGS));
    }

    pub fn unref(self: *Context) void {
        xkb.xkb_context_unref(@ptrCast(self));
    }
};

pub const Keymap = opaque {
    pub fn newFromString(
        ctx: *Context,
        string: [*:0]const u8,
        format: KeymapFormat,
        flags: KeymapCompileFlags,
    ) ?*Keymap {
        return @ptrCast(xkb.xkb_keymap_new_from_string(
            @ptrCast(ctx),
            string,
            @intFromEnum(format),
            @intFromEnum(flags),
        ));
    }

    pub fn unref(self: *Keymap) void {
        xkb.xkb_keymap_unref(@ptrCast(self));
    }
};

pub const State = opaque {
    pub fn new(keymap: *Keymap) ?*State {
        return @ptrCast(xkb.xkb_state_new(@ptrCast(keymap)));
    }

    pub fn updateMask(
        self: *State,
        mods_depressed: u32,
        mods_latched: u32,
        mods_locked: u32,
        depressed_layout: u32,
        latched_layout: u32,
        locked_layout: u32,
    ) void {
        _ = xkb.xkb_state_update_mask(
            @ptrCast(self),
            mods_depressed,
            mods_latched,
            mods_locked,
            depressed_layout,
            latched_layout,
            locked_layout,
        );
    }

    pub fn keyGetOneSym(self: *State, keycode: u32) u32 {
        return xkb.xkb_state_key_get_one_sym(@ptrCast(self), keycode);
    }

    pub fn keyGetUtf8(self: *State, keycode: u32, buffer: []u8) i32 {
        return xkb.xkb_state_key_get_utf8(
            @ptrCast(self),
            keycode,
            buffer.ptr,
            buffer.len,
        );
    }

    pub fn unref(self: *State) void {
        xkb.xkb_state_unref(@ptrCast(self));
    }
};

pub const KeymapFormat = enum(c_uint) {
    text_v1 = 1,
};

pub const KeymapCompileFlags = enum(c_uint) {
    no_flags = 0,
};

pub const Keysym = enum(u32) {
    backspace = 0xff08,
    escape = 0xff1b,
    return_ = 0xff0d,
    up = 0xff52,
    down = 0xff54,
    _,
};
