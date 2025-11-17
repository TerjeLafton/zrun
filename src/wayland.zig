const std = @import("std");
const assert = std.debug.assert;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const xdg = wayland.client.xdg;
const zwlr = wayland.client.zwlr;

const xkb = @import("xkb.zig");

const KeyboardState = struct {
    xkb_context: *xkb.Context,
    xkb_keymap: ?*xkb.Keymap,
    xkb_state: ?*xkb.State,
    selected_index: usize,
    app_count: usize,
    running: *bool,
    needs_redraw: bool,
    launch_selected: bool,
    search_query: [256]u8,
    search_query_len: usize,

    pub fn init(running: *bool) !KeyboardState {
        const ctx = xkb.Context.new() orelse return error.XkbContextCreateFailed;
        return .{
            .xkb_context = ctx,
            .xkb_keymap = null,
            .xkb_state = null,
            .selected_index = 0,
            .app_count = 0,
            .running = running,
            .needs_redraw = false,
            .launch_selected = false,
            .search_query = undefined,
            .search_query_len = 0,
        };
    }

    pub fn getSearchQuery(self: *const KeyboardState) []const u8 {
        return self.search_query[0..self.search_query_len];
    }

    pub fn deinit(self: *KeyboardState) void {
        if (self.xkb_state) |state| state.unref();
        if (self.xkb_keymap) |keymap| keymap.unref();
        self.xkb_context.unref();
    }
};

const Context = struct {
    compositor: ?*wl.Compositor,
    shm: ?*wl.Shm,
    layer_shell: ?*zwlr.LayerShellV1,
    seat: ?*wl.Seat,
};

pub const App = struct {
    display: *wl.Display,
    compositor: *wl.Compositor,
    shm: *wl.Shm,
    layer_shell: *zwlr.LayerShellV1,
    seat: *wl.Seat,
    keyboard: ?*wl.Keyboard,
    surface: *wl.Surface,
    layer_surface: *zwlr.LayerSurfaceV1,
    buffer: ?*wl.Buffer,
    configure_data: ConfigureData,
    keyboard_state: KeyboardState,

    pub fn init() !App {
        const display = try wl.Display.connect(null);
        errdefer display.disconnect();

        var ctx: Context = .{
            .compositor = null,
            .shm = null,
            .layer_shell = null,
            .seat = null,
        };

        const registry = try display.getRegistry();
        registry.setListener(*Context, registryListener, &ctx);
        if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

        const compositor = ctx.compositor orelse return error.NoWlCompositor;
        const shm = ctx.shm orelse return error.NoWlShm;
        const layer_shell = ctx.layer_shell orelse return error.NoLayerShell;
        const seat = ctx.seat orelse return error.NoWlSeat;

        const surface = try compositor.createSurface();
        errdefer surface.destroy();

        const layer_surface = try layer_shell.getLayerSurface(
            surface,
            null,
            .overlay,
            "zrun",
        );
        errdefer layer_surface.destroy();

        // Note: keyboard_state.running will be updated after init() returns
        // since we can't get a stable pointer to configure_data.running here
        var temp_running: bool = true;
        var keyboard_state = try KeyboardState.init(&temp_running);
        errdefer keyboard_state.deinit();

        return .{
            .display = display,
            .compositor = compositor,
            .shm = shm,
            .layer_shell = layer_shell,
            .seat = seat,
            .keyboard = null,
            .surface = surface,
            .layer_surface = layer_surface,
            .buffer = null,
            .configure_data = .{
                .running = true,
                .width = 0,
                .height = 0,
                .configured = false,
            },
            .keyboard_state = keyboard_state,
        };
    }

    pub fn configure(self: *App) !struct { width: u32, height: u32 } {
        self.layer_surface.setSize(0, 0);
        self.layer_surface.setAnchor(.{ .top = true, .bottom = true, .left = true, .right = true });
        self.layer_surface.setExclusiveZone(-1);
        self.layer_surface.setKeyboardInteractivity(.exclusive);
        self.layer_surface.setListener(*ConfigureData, layerSurfaceListener, &self.configure_data);

        self.surface.commit();

        while (!self.configure_data.configured) {
            if (self.display.dispatch() != .SUCCESS) return error.DispatchFailed;
        }

        return .{
            .width = self.configure_data.width,
            .height = self.configure_data.height,
        };
    }

    pub fn setupKeyboard(self: *App, app_count: usize) !void {
        self.keyboard_state.app_count = app_count;
        const keyboard = try self.seat.getKeyboard();
        keyboard.setListener(*KeyboardState, keyboardListener, &self.keyboard_state);
        self.keyboard = keyboard;
    }

    pub fn roundtrip(self: *App) !void {
        if (self.display.roundtrip() != .SUCCESS) return error.RoundtripFailed;
    }

    pub fn needsRedraw(self: *App) bool {
        if (self.keyboard_state.needs_redraw) {
            self.keyboard_state.needs_redraw = false;
            return true;
        }
        return false;
    }

    pub fn getSelectedIndex(self: *App) usize {
        return self.keyboard_state.selected_index;
    }

    pub fn shouldLaunch(self: *App) bool {
        return self.keyboard_state.launch_selected;
    }

    pub fn getSearchQuery(self: *App) []const u8 {
        return self.keyboard_state.getSearchQuery();
    }

    pub fn setBuffer(self: *App, pixel_data: []const u8, width: i32, height: i32) !void {
        const buffer = try createBuffer(self.shm, width, height, pixel_data);
        self.buffer = buffer;

        self.surface.attach(buffer, 0, 0);
        self.surface.damage(0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
        self.surface.commit();
    }

    pub fn run(self: *App) !void {
        while (self.configure_data.running) {
            if (self.display.dispatch() != .SUCCESS) return error.DispatchFailed;
        }
    }

    pub fn deinit(self: *App) void {
        self.keyboard_state.deinit();
        if (self.keyboard) |kb| {
            kb.release();
        }
        self.layer_surface.destroy();
        self.surface.destroy();
        if (self.buffer) |buffer| {
            buffer.destroy();
        }
        self.display.disconnect();
    }
};

pub fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, context: *Context) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = registry.bind(global.name, wl.Compositor, 6) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                context.shm = registry.bind(global.name, wl.Shm, 1) catch return;
            } else if (std.mem.orderZ(u8, global.interface, zwlr.LayerShellV1.interface.name) == .eq) {
                context.layer_shell = registry.bind(global.name, zwlr.LayerShellV1, 5) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Seat.interface.name) == .eq) {
                context.seat = registry.bind(global.name, wl.Seat, 9) catch return;
            }
        },
        .global_remove => {},
    }
}

const ConfigureData = struct {
    running: bool,
    width: u32,
    height: u32,
    configured: bool,
};

pub fn keyboardListener(keyboard: *wl.Keyboard, event: wl.Keyboard.Event, state: *KeyboardState) void {
    _ = keyboard;
    switch (event) {
        .keymap => |keymap| {
            const map_size: usize = @intCast(keymap.size);
            const map = std.posix.mmap(
                null,
                map_size,
                std.posix.PROT.READ,
                .{ .TYPE = .PRIVATE },
                keymap.fd,
                0,
            ) catch return;
            defer std.posix.munmap(map);

            const keymap_str: [*:0]const u8 = @ptrCast(map.ptr);
            const km = xkb.Keymap.newFromString(
                state.xkb_context,
                keymap_str,
                .text_v1,
                .no_flags,
            ) orelse return;

            const xkb_state = xkb.State.new(km) orelse {
                km.unref();
                return;
            };

            if (state.xkb_state) |old_state| old_state.unref();
            if (state.xkb_keymap) |old_keymap| old_keymap.unref();

            state.xkb_keymap = km;
            state.xkb_state = xkb_state;
        },
        .enter => {},
        .leave => {},
        .key => |key| {
            if (state.xkb_state) |xkb_state| {
                const keycode = key.key + 8;
                const keysym: xkb.Keysym = @enumFromInt(xkb_state.keyGetOneSym(keycode));

                if (key.state == .pressed) {
                    var buf: [8]u8 = undefined;
                    const len = xkb_state.keyGetUtf8(keycode, &buf);
                    const text = if (len > 0) buf[0..@intCast(len)] else &[_]u8{};

                    handleKey(state, keysym, text);
                }
            }
        },
        .modifiers => |mods| {
            if (state.xkb_state) |xkb_state| {
                xkb_state.updateMask(
                    mods.mods_depressed,
                    mods.mods_latched,
                    mods.mods_locked,
                    0,
                    0,
                    mods.group,
                );
            }
        },
        .repeat_info => {},
    }
}

fn handleKey(state: *KeyboardState, keysym: xkb.Keysym, text: []const u8) void {
    switch (keysym) {
        .escape => {
            state.running.* = false;
        },
        .return_ => {
            state.launch_selected = true;
            state.running.* = false;
        },
        .backspace => {
            if (state.search_query_len > 0) {
                state.search_query_len -= 1;
                state.selected_index = 0;
                state.needs_redraw = true;
            }
        },
        .up => {
            if (state.selected_index > 0) {
                state.selected_index -= 1;
                state.needs_redraw = true;
            }
        },
        .down => {
            if (state.selected_index + 1 < state.app_count) {
                state.selected_index += 1;
                state.needs_redraw = true;
            }
        },
        else => {
            if (text.len > 0 and text.len < 8) {
                if (state.search_query_len + text.len < state.search_query.len) {
                    for (text) |c| {
                        state.search_query[state.search_query_len] = c;
                        state.search_query_len += 1;
                    }
                    state.selected_index = 0;
                    state.needs_redraw = true;
                }
            }
        },
    }
}

pub fn layerSurfaceListener(layer_surface: *zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, data: *ConfigureData) void {
    switch (event) {
        .configure => |configure| {
            data.width = configure.width;
            data.height = configure.height;
            data.configured = true;
            layer_surface.ackConfigure(configure.serial);
        },
        .closed => {
            data.running = false;
        },
    }
}

pub fn createBuffer(shm: *wl.Shm, width: i32, height: i32, pixel_data: []const u8) !*wl.Buffer {
    const stride = width * 4;
    const size: usize = @intCast(stride * height);

    assert(pixel_data.len == size);

    const fd = try std.posix.memfd_create("wl_shm", 0);
    errdefer std.posix.close(fd);

    try std.posix.ftruncate(fd, size);

    const data = try std.posix.mmap(
        null,
        size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .SHARED },
        fd,
        0,
    );
    defer std.posix.munmap(data);

    @memcpy(data, pixel_data);

    const pool = try shm.createPool(fd, @intCast(size));
    defer pool.destroy();

    return try pool.createBuffer(0, width, height, stride, wl.Shm.Format.argb8888);
}
