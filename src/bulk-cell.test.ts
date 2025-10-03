import { test, expect } from "bun:test";
import { createTerminal } from "./index.js";

test("getRow returns all cells in a row", () => {
    const terminal = createTerminal({
        cols: 10,
        rows: 5,
        onWrite: () => {},
    });

    terminal.write("Hello");

    const row = terminal.getRow(0);
    expect(row.length).toBe(10);
    expect(row[0]!.text).toBe("H");
    expect(row[1]!.text).toBe("e");
    expect(row[2]!.text).toBe("l");
    expect(row[3]!.text).toBe("l");
    expect(row[4]!.text).toBe("o");
    expect(row[5]!.text).toBe("");

    terminal.dispose();
});

test("getRow with styled content", () => {
    const terminal = createTerminal({
        cols: 10,
        rows: 5,
        onWrite: () => {},
    });

    terminal.write("\x1B[1;31mRed\x1B[0m");

    const row = terminal.getRow(0);
    expect(row[0]!.text).toBe("R");
    expect(row[0]!.bold).toBe(true);
    expect(row[0]!.fg.type).toBe(1);
    expect(row[0]!.fg.paletteIdx).toBe(1);

    terminal.dispose();
});

test("getRow on different rows", () => {
    const terminal = createTerminal({
        cols: 10,
        rows: 5,
        onWrite: () => {},
    });

    terminal.write("Line1\r\nLine2\r\nLine3");

    const row0 = terminal.getRow(0);
    const row1 = terminal.getRow(1);
    const row2 = terminal.getRow(2);

    expect(row0[0]!.text).toBe("L");
    expect(row0[4]!.text).toBe("1");
    expect(row1[0]!.text).toBe("L");
    expect(row1[4]!.text).toBe("2");
    expect(row2[0]!.text).toBe("L");
    expect(row2[4]!.text).toBe("3");

    terminal.dispose();
});

test("getRegion returns cells in rectangular area", () => {
    const terminal = createTerminal({
        cols: 10,
        rows: 5,
        onWrite: () => {},
    });

    terminal.write("ABCDEFGHIJ\r\nKLMNOPQRST\r\nUVWXYZ1234");

    const region = terminal.getRegion(0, 2, 1, 5);
    expect(region.length).toBe(2); // 2 rows
    expect(region[0]!.length).toBe(4); // 4 cols (2,3,4,5)

    expect(region[0]![0]!.text).toBe("C");
    expect(region[0]![1]!.text).toBe("D");
    expect(region[0]![2]!.text).toBe("E");
    expect(region[0]![3]!.text).toBe("F");

    expect(region[1]![0]!.text).toBe("M");
    expect(region[1]![1]!.text).toBe("N");
    expect(region[1]![2]!.text).toBe("O");
    expect(region[1]![3]!.text).toBe("P");

    terminal.dispose();
});

test("getRegion with single cell", () => {
    const terminal = createTerminal({
        cols: 10,
        rows: 5,
        onWrite: () => {},
    });

    terminal.write("Hello");

    const region = terminal.getRegion(0, 1, 0, 1);
    expect(region.length).toBe(1);
    expect(region[0]!.length).toBe(1);
    expect(region[0]![0]!.text).toBe("e");

    terminal.dispose();
});

test("getRegion with styled content", () => {
    const terminal = createTerminal({
        cols: 10,
        rows: 5,
        onWrite: () => {},
    });

    terminal.write("\x1B[1mBold\x1B[0m\r\nNorm");

    const region = terminal.getRegion(0, 0, 1, 2);
    expect(region[0]![0]!.bold).toBe(true);
    expect(region[0]![1]!.bold).toBe(true);
    expect(region[1]![0]!.bold).toBe(false);

    terminal.dispose();
});

test("getAllCells returns all terminal content", () => {
    const terminal = createTerminal({
        cols: 5,
        rows: 3,
        onWrite: () => {},
    });

    terminal.write("ABCDE\r\nFGHIJ\r\nKLMNO");

    const allCells = terminal.getAllCells();
    expect(allCells.length).toBe(3); // 3 rows
    expect(allCells[0]!.length).toBe(5); // 5 cols

    expect(allCells[0]![0]!.text).toBe("A");
    expect(allCells[0]![4]!.text).toBe("E");
    expect(allCells[1]![0]!.text).toBe("F");
    expect(allCells[1]![4]!.text).toBe("J");
    expect(allCells[2]![0]!.text).toBe("K");
    expect(allCells[2]![4]!.text).toBe("O");

    terminal.dispose();
});

test("getAllCells with mixed styled and unstyled content", () => {
    const terminal = createTerminal({
        cols: 5,
        rows: 2,
        onWrite: () => {},
    });

    terminal.write("\x1B[31mRed\x1B[0m\r\n\x1B[1mBold");

    const allCells = terminal.getAllCells();

    // First row - red text
    expect(allCells[0]![0]!.fg.type).toBe(1);
    expect(allCells[0]![0]!.fg.paletteIdx).toBe(1);

    // Second row - bold text
    expect(allCells[1]![0]!.bold).toBe(true);

    terminal.dispose();
});

test("getAllCells with empty terminal", () => {
    const terminal = createTerminal({
        cols: 3,
        rows: 2,
        onWrite: () => {},
    });

    const allCells = terminal.getAllCells();
    expect(allCells.length).toBe(2);
    expect(allCells[0]!.length).toBe(3);
    expect(allCells[0]![0]!.text).toBe("");
    expect(allCells[1]![2]!.text).toBe("");

    terminal.dispose();
});
