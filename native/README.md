# Ghostty VT Terminal Emulator API

This document describes the public Zig API for the `ghostty-vt` module used in this project.

## Source Location

The ghostty-vt dependency source code can be found using:

```bash
zig env  # Get the global cache directory
# Look for: /path/to/.cache/zig/p/ghostty-*/src/
```

The public API is defined in `src/lib_vt.zig`.

## Public API Overview

The API is exported from `src/lib_vt.zig` and re-exports components from the internal `terminal` module.

### Core Types

#### Terminal

**Type:** `Terminal`  
**Source:** `terminal/Terminal.zig`

The primary terminal emulation structure representing a single terminal containing a grid of characters. Maintains the scrollback buffer and exposes operations on the terminal grid.

Key features:

- Primary and alternate screen buffers
- Scrollback history
- Color palette management
- Tab stops
- Terminal modes
- Mouse tracking
- Selection support

#### Parser

**Type:** `Parser`  
**Source:** `terminal/Parser.zig`

VT-series parser for escape and control sequences. Implements the state machine described on [vt100.net](https://vt100.net/emu/dec_ansi_parser).

Parse actions:

- `print`: Draw character to screen (unicode codepoint)
- `execute`: Execute C0/C1 control function
- `csi_dispatch`: Execute CSI command
- `esc_dispatch`: Execute ESC command
- `osc_dispatch`: Execute OSC command
- `dcs_hook`/`dcs_put`/`dcs_unhook`: DCS-related events
- `apc_start`/`apc_put`/`apc_end`: APC data

#### Screen

**Type:** `Screen`  
**Source:** `terminal/Screen.zig`

Screen state management including cursor position, pages, selection, and charsets.

Key components:

- `Cursor`: Cursor position and style
- `CursorStyle`: Visual cursor appearance (block, underline, bar)
- Page list for scrollback
- Selection tracking
- Charset state
- Kitty graphics protocol support

#### Page & PageList

**Type:** `Page`, `PageList`  
**Source:** `terminal/page.zig`, `terminal/PageList.zig`

`Page` represents a single page of terminal content (grid of cells).  
`PageList` manages the list of pages for scrollback history.

#### Cell

**Type:** `Cell`  
**Source:** `terminal/page.zig`

Represents a single character cell in the terminal grid with associated styling.

### Coordinate & Positioning

#### Point

**Type:** `Point`  
**Source:** `terminal/point.zig`

Terminal grid coordinate with x/y position.

#### Coordinate

**Type:** `Coordinate`  
**Source:** `terminal/point.zig`

A coordinate value (row or column index).

#### size

**Namespace:** `size`  
**Source:** `terminal/size.zig`

Terminal size utilities and types.

### Terminal Commands

#### CSI (Control Sequence Introducer)

**Type:** `CSI`  
**Source:** `Parser.Action.CSI`

CSI escape sequences (e.g., cursor movement, text formatting).

Fields:

- `intermediates`: Intermediate bytes
- `params`: Parameter values
- `params_sep`: Parameter separators (semicolon/colon)
- `final`: Final byte

#### DCS (Device Control String)

**Type:** `DCS`  
**Source:** `Parser.Action.DCS`

Device control string sequences.

#### OSC (Operating System Command)

**Namespace:** `osc`  
**Source:** `terminal/osc.zig`

Operating system commands (e.g., setting window title, colors, hyperlinks).

#### APC (Application Program Command)

**Namespace:** `apc`  
**Source:** `terminal/apc.zig`

Application program commands.

### Styling & Color

#### Style

**Type:** `Style`  
**Source:** `terminal/style.zig`

Text style attributes (bold, italic, underline, etc.).

#### Attribute

**Type:** `Attribute`  
**Source:** `terminal/sgr.zig`

SGR (Select Graphic Rendition) attributes.

#### color

**Namespace:** `color`  
**Source:** `terminal/color.zig`

Color types and palette management.

#### x11_color

**Namespace:** `x11_color`  
**Source:** `terminal/x11_color.zig`

X11 color name parsing.

### Terminal Modes

#### Mode

**Type:** `Mode`  
**Source:** `terminal/modes.zig`

Terminal mode enumeration (e.g., cursor keys mode, auto-wrap).

#### ModePacked

**Type:** `ModePacked`  
**Source:** `terminal/modes.zig`

Packed representation of terminal modes.

### Input & Mouse

#### MouseShape

**Type:** `MouseShape`  
**Source:** `terminal/mouse_shape.zig`

Mouse cursor shape.

### Screen Operations

#### ScreenType

**Type:** `ScreenType`  
**Source:** `Terminal.ScreenType`

Enum for primary vs. alternate screen.

Values:

- `primary`: Main screen with scrollback
- `alternate`: Alternate screen (no scrollback)

#### EraseDisplay

**Type:** `EraseDisplay`  
**Source:** `terminal/csi.zig`

Erase display modes (clear screen operations).

#### EraseLine

**Type:** `EraseLine`  
**Source:** `terminal/csi.zig`

Erase line modes (clear line operations).

#### TabClear

**Type:** `TabClear`  
**Source:** `terminal/csi.zig`

Tab stop clearing operations.

### Selection & Search

#### Selection

**Type:** `Selection`  
**Source:** `terminal/Selection.zig`

Terminal text selection.

#### search

**Namespace:** `search`  
**Source:** `terminal/search.zig`

Text search functionality.

### Charsets

#### Charset

**Type:** `Charset`  
**Source:** `terminal/charsets.zig`

Character set definitions.

#### CharsetSlot

**Type:** `CharsetSlot`  
**Source:** `terminal/charsets.zig`

Character set slots (G0-G3).

#### CharsetActiveSlot

**Type:** `CharsetActiveSlot`  
**Source:** `terminal/charsets.zig`

Active character set slot selection.

### Miscellaneous

#### Stream

**Type:** `Stream`  
**Source:** `terminal/stream.zig`

Terminal data stream handling.

#### StringMap

**Type:** `StringMap`  
**Source:** `terminal/StringMap.zig`

String storage and mapping.

#### Pin

**Type:** `Pin`  
**Source:** `PageList.Pin`

Pin for tracking positions in the page list.

#### parse_table

**Namespace:** `parse_table`  
**Source:** `terminal/parse_table.zig`

VT parser state transition table.

#### device_status

**Namespace:** `device_status`  
**Source:** `terminal/device_status.zig`

Device status report handling.

#### kitty

**Namespace:** `kitty`  
**Source:** `terminal/kitty.zig`

Kitty terminal protocol extensions.

#### modes

**Namespace:** `modes`  
**Source:** `terminal/modes.zig`

Terminal mode definitions and utilities.

#### CursorStyle

**Type:** `CursorStyle`  
**Source:** `Screen.CursorStyle`

Visual cursor style (block, beam, underline).

#### CursorStyleReq

**Type:** `CursorStyleReq`  
**Source:** `terminal/ansi.zig`

Cursor style request type.

#### DeviceAttributeReq

**Type:** `DeviceAttributeReq`  
**Source:** `terminal/ansi.zig`

Device attribute request type.

#### ModifyKeyFormat

**Type:** `ModifyKeyFormat`  
**Source:** `terminal/ansi.zig`

Modified key format for keyboard handling.

#### ProtectedMode

**Type:** `ProtectedMode`  
**Source:** `terminal/ansi.zig`

Protected mode for selective erase operations.

#### StatusLineType

**Type:** `StatusLineType`  
**Source:** `terminal/ansi.zig`

Status line type.

#### StatusDisplay

**Type:** `StatusDisplay`  
**Source:** `terminal/ansi.zig`

Status display control.

#### SizeReportStyle

**Type:** `SizeReportStyle`  
**Source:** `terminal/csi.zig`

Terminal size report style.
