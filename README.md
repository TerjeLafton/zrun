# zrun

A fast and minimal application launcher for Wayland, written in Zig.

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
