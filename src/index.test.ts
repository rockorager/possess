import { test, expect } from "bun:test";
import { createTerminal } from "./index.js";

test("createTerminal creates a terminal instance", () => {
    const writtenData: Uint8Array[] = [];

    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: (data) => {
            writtenData.push(data);
        },
    });

    expect(terminal).toBeDefined();
    expect(terminal.write).toBeDefined();
    expect(terminal.dispose).toBeDefined();

    terminal.dispose();
});

test("terminal responds to device status report", () => {
    const writtenData: Uint8Array[] = [];

    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: (data) => {
            writtenData.push(data);
        },
    });

    // Send device status report request (ESC [ 5 n) - using string
    terminal.write("\x1B[5n");

    // Should receive operating status response
    expect(writtenData.length).toBe(1);
    expect(Buffer.from(writtenData[0]!).toString()).toBe("\x1B[0n");

    terminal.dispose();
});

test("terminal responds to cursor position request", () => {
    const writtenData: Uint8Array[] = [];

    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: (data) => {
            writtenData.push(data);
        },
    });

    // Send cursor position report request (ESC [ 6 n) - using Uint8Array
    terminal.write(Buffer.from("\x1B[6n"));

    // Should receive cursor position response (row 1, col 1 initially)
    expect(writtenData.length).toBe(1);
    expect(Buffer.from(writtenData[0]!).toString()).toBe("\x1B[1;1R");

    terminal.dispose();
});

test("terminal accepts both string and Uint8Array", () => {
    const writtenData: Uint8Array[] = [];

    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: (data) => {
            writtenData.push(data);
        },
    });

    // Test with string
    terminal.write("hello");

    // Test with Uint8Array
    terminal.write(new Uint8Array([119, 111, 114, 108, 100])); // "world"

    terminal.dispose();
});
