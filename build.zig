const std = @import("std");
const Build = std.Build;

const Scanner = @import("wayland").Scanner;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = Scanner.create(b, .{});
    const wayland = b.createModule(.{ .root_source_file = scanner.result });

    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addCustomProtocol(.{ .cwd_relative = "/usr/share/wlr-protocols/unstable/wlr-layer-shell-unstable-v1.xml" });

    scanner.generate("wl_compositor", 6);
    scanner.generate("wl_shm", 1);
    scanner.generate("wl_output", 4);
    scanner.generate("wl_seat", 9);
    scanner.generate("xdg_wm_base", 7);
    scanner.generate("zwlr_layer_shell_v1", 5);

    const mod = b.addModule("zrun", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
        .imports = &.{
            .{ .name = "wayland", .module = wayland },
        },
    });

    const exe = b.addExecutable(.{
        .name = "zrun",
        .root_module = mod,
    });
    exe.linkLibC();
    exe.linkSystemLibrary("wayland-client");
    exe.linkSystemLibrary("cairo");
    exe.linkSystemLibrary("pangocairo");
    exe.linkSystemLibrary("xkbcommon");

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_check = b.addExecutable(.{
        .name = "zrun",
        .root_module = mod,
    });
    const check = b.step("check", "Check if zrun compiles");
    check.dependOn(&exe_check.step);
}
