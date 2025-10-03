import { test, expect } from "bun:test";
import { createTerminal } from "./index.js";

test("getMode returns false for disabled modes", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onData: () => {},
    });

    // Mode 2026 (synchronized output) should be disabled by default
    expect(terminal.getMode(2026)).toBe(false);

    // Mode 2004 (bracketed paste) should be disabled by default
    expect(terminal.getMode(2004)).toBe(false);

    terminal.dispose();
});

test("getMode returns true when synchronized output is enabled", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onData: () => {},
    });

    // Enable synchronized output mode (CSI ? 2026 h)
    terminal.write("\x1B[?2026h");

    expect(terminal.getMode(2026)).toBe(true);

    terminal.dispose();
});

test("getMode returns false when synchronized output is disabled", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onData: () => {},
    });

    // Enable then disable synchronized output mode
    terminal.write("\x1B[?2026h");
    expect(terminal.getMode(2026)).toBe(true);

    terminal.write("\x1B[?2026l");
    expect(terminal.getMode(2026)).toBe(false);

    terminal.dispose();
});

test("isSyncModeEnabled returns true when mode is enabled", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onData: () => {},
    });

    // Enable synchronized output mode
    terminal.write("\x1B[?2026h");

    expect(terminal.isSyncModeEnabled()).toBe(true);

    terminal.dispose();
});

test("isSyncModeEnabled returns false when mode is disabled", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onData: () => {},
    });

    // Enable then disable
    terminal.write("\x1B[?2026h");
    expect(terminal.isSyncModeEnabled()).toBe(true);

    terminal.write("\x1B[?2026l");
    expect(terminal.isSyncModeEnabled()).toBe(false);

    terminal.dispose();
});

test("getMode works with bracketed paste mode", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onData: () => {},
    });

    expect(terminal.getMode(2004)).toBe(false);

    // Enable bracketed paste (CSI ? 2004 h)
    terminal.write("\x1B[?2004h");
    expect(terminal.getMode(2004)).toBe(true);

    // Disable bracketed paste (CSI ? 2004 l)
    terminal.write("\x1B[?2004l");
    expect(terminal.getMode(2004)).toBe(false);

    terminal.dispose();
});

test("getMode returns false for unknown mode numbers", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onData: () => {},
    });

    // Test with a valid mode number that doesn't exist
    expect(terminal.getMode(9999)).toBe(false);

    terminal.dispose();
});

test("getMode returns false for invalid mode numbers > 65535", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onData: () => {},
    });

    // Mode numbers that don't fit in u16 should return false
    expect(terminal.getMode(99999)).toBe(false);
    expect(terminal.getMode(1000000)).toBe(false);

    terminal.dispose();
});
