const std = @import("std");

const drawing = @import("drawing.zig");
const wayland = @import("wayland.zig");

const Launcher = @This();

allocator: std.mem.Allocator,
applications: std.StringHashMap([]const u8),

pub fn init(allocator: std.mem.Allocator) Launcher {
    return .{
        .allocator = allocator,
        .applications = std.StringHashMap([]const u8).init(allocator),
    };
}

pub fn run(self: *Launcher) !void {
    try self.findDesktopFiles();

    var app = try wayland.App.init();
    defer app.deinit();

    app.keyboard_state.running = &app.configure_data.running;

    const size = try app.configure();
    const width: i32 = @intCast(size.width);
    const height: i32 = @intCast(size.height);

    var app_names = std.ArrayList([]const u8){};
    var iter = self.applications.keyIterator();
    while (iter.next()) |name| {
        try app_names.append(self.allocator, name.*);
    }

    try app.setupKeyboard(app_names.items.len);
    try app.roundtrip();

    const search_query = app.getSearchQuery();
    const filtered_apps = try self.filterApps(app_names.items, search_query);
    app.keyboard_state.app_count = filtered_apps.items.len;

    const pixels = try drawing.drawWithCairo(self.allocator, width, height, filtered_apps.items, 0, search_query);
    try app.setBuffer(pixels, width, height);

    while (app.configure_data.running) {
        if (app.needsRedraw()) {
            const selected_index = app.getSelectedIndex();
            const current_query = app.getSearchQuery();
            const current_filtered = try self.filterApps(app_names.items, current_query);

            app.keyboard_state.app_count = current_filtered.items.len;

            const new_pixels = try drawing.drawWithCairo(self.allocator, width, height, current_filtered.items, selected_index, current_query);

            if (app.buffer) |old_buffer| {
                old_buffer.destroy();
            }
            try app.setBuffer(new_pixels, width, height);
        }

        if (app.display.dispatch() != .SUCCESS) return error.DispatchFailed;
    }

    if (app.shouldLaunch()) {
        const selected_index = app.getSelectedIndex();
        const final_query = app.getSearchQuery();
        const final_filtered = try self.filterApps(app_names.items, final_query);

        if (selected_index < final_filtered.items.len) {
            const app_name = final_filtered.items[selected_index];
            if (self.applications.get(app_name)) |desktop_path| {
                try self.launchApp(desktop_path);
            }
        }
    }
}

fn filterApps(self: *Launcher, all_apps: []const []const u8, query: []const u8) !std.ArrayList([]const u8) {
    var filtered = std.ArrayList([]const u8){};

    if (query.len == 0) {
        for (all_apps) |app| {
            try filtered.append(self.allocator, app);
        }
        return filtered;
    }

    for (all_apps) |app| {
        if (containsIgnoreCase(app, query)) {
            try filtered.append(self.allocator, app);
        }
    }

    return filtered;
}

/// Check if haystack contains needle (case-insensitive)
fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    while (i <= haystack.len - needle.len) : (i += 1) {
        var match = true;
        for (needle, 0..) |c, j| {
            const h = haystack[i + j];
            if (toLower(h) != toLower(c)) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn launchApp(self: *Launcher, desktop_path: []const u8) !void {
    var child = std.process.Child.init(&.{ "gio", "launch", desktop_path }, self.allocator);
    _ = try child.spawnAndWait();
}

fn findDesktopFiles(self: *Launcher) !void {
    var buf: [std.fs.max_path_bytes]u8 = undefined;

    if (std.posix.getenv("XDG_DATA_HOME")) |xdg_data_home| {
        const app_dir = try std.fmt.bufPrint(&buf, "{s}/applications", .{xdg_data_home});
        self.scanDirectory(app_dir) catch |err| {
            if (err != error.FileNotFound) {
                std.debug.print("Warning: Failed to scan {s}: {}\n", .{ app_dir, err });
            }
        };
    } else if (std.posix.getenv("HOME")) |home| {
        const app_dir = try std.fmt.bufPrint(&buf, "{s}/.local/share/applications", .{home});
        self.scanDirectory(app_dir) catch |err| {
            if (err != error.FileNotFound) {
                std.debug.print("Warning: Failed to scan {s}: {}\n", .{ app_dir, err });
            }
        };
    }

    const xdg_data_dirs = std.posix.getenv("XDG_DATA_DIRS") orelse "/usr/local/share:/usr/share";
    var iter = std.mem.splitScalar(u8, xdg_data_dirs, ':');
    while (iter.next()) |dir| {
        if (dir.len == 0) continue;
        const app_dir = try std.fmt.bufPrint(&buf, "{s}/applications", .{dir});
        self.scanDirectory(app_dir) catch |err| {
            if (err != error.FileNotFound) {
                std.debug.print("Warning: Failed to scan {s}: {}\n", .{ app_dir, err });
            }
        };
    }
}

fn parseDesktopFile(self: *Launcher, file_path: []const u8) !?[]const u8 {
    const file = std.fs.openFileAbsolute(file_path, .{}) catch |err| {
        std.debug.print("Warning: Failed to open {s}: {}\n", .{ file_path, err });
        return null;
    };
    defer file.close();

    var read_buf: [1024]u8 = undefined;
    var reader = file.reader(&read_buf);

    while (try reader.interface.takeDelimiter('\n')) |line| {
        if (std.mem.startsWith(u8, line, "Name=")) {
            const name = line[5..];
            return try self.allocator.dupe(u8, name);
        }
    }

    return null;
}

fn scanDirectory(self: *Launcher, dir_path: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(dir_path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.endsWith(u8, entry.name, ".desktop")) {
            const full_path = try std.fmt.allocPrint(
                self.allocator,
                "{s}/{s}",
                .{ dir_path, entry.name },
            );
            errdefer self.allocator.free(full_path);

            if (try self.parseDesktopFile(full_path)) |name| {
                const result = try self.applications.getOrPut(name);
                if (result.found_existing) {
                    self.allocator.free(name);
                    self.allocator.free(full_path);
                } else {
                    result.value_ptr.* = full_path;
                }
            } else {
                self.allocator.free(full_path);
            }
        }
    }
}
