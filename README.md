# zrun

A fast and minimal application launcher for Wayland, written in Zig.

<img width="3840" height="2114" alt="image" src="https://github.com/user-attachments/assets/bfa66c90-e6f1-4fb2-91ec-0f52487cb74a" />

## About

This project is a learning exercise in Wayland protocol programming. Unlike many launchers that use high-level GUI toolkits, zrun interfaces directly with Wayland using:

- **Wayland protocols** - Direct protocol implementation using wlr-layer-shell for overlay rendering
- **Cairo** - 2D graphics rendering
- **Pango** - Text layout and font rendering
- **xkbcommon** - Keyboard input handling

The goal is to understand how Wayland compositors work at a lower level while building a useful, fast application launcher.

## Requirements

- Zig 0.15+
- Wayland compositor with wlr-layer-shell support
- libwayland-client
- cairo
- pangocairo
- xkbcommon

## Build

```bash
zig build
```

## Run

```bash
zig build run
```

## Install

Install to `~/.local/bin`:

```bash
zig build --prefix ~/.local
```

Make sure `~/.local/bin` is in your `$PATH`.

## Usage

- Type to search for applications
- **Up/Down**: Navigate through results
- **Enter**: Launch selected application
- **Backspace**: Delete search characters
- **Esc**: Exit without launching
