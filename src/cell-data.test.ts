import { test, expect } from "bun:test";
import { createTerminal } from "./index.js";

test("getScreenDimensions returns terminal dimensions", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    const dims = terminal.getScreenDimensions();
    expect(dims.rows).toBe(24);
    expect(dims.cols).toBe(80);

    terminal.dispose();
});

test("getCellData returns text content at correct positions", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("Hello");

    expect(terminal.getCellData(0, 0).text).toBe("H");
    expect(terminal.getCellData(0, 1).text).toBe("e");
    expect(terminal.getCellData(0, 2).text).toBe("l");
    expect(terminal.getCellData(0, 3).text).toBe("l");
    expect(terminal.getCellData(0, 4).text).toBe("o");
    expect(terminal.getCellData(0, 5).text).toBe("");

    terminal.dispose();
});

test("getCellData returns bold style", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[1mBold\x1B[0m Normal");

    const boldCell = terminal.getCellData(0, 0);
    expect(boldCell.text).toBe("B");
    expect(boldCell.bold).toBe(true);

    const normalCell = terminal.getCellData(0, 5);
    expect(normalCell.text).toBe("N");
    expect(normalCell.bold).toBe(false);

    terminal.dispose();
});

test("getCellData returns italic style", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[3mItalic\x1B[0m");

    const italicCell = terminal.getCellData(0, 0);
    expect(italicCell.text).toBe("I");
    expect(italicCell.italic).toBe(true);
    expect(italicCell.bold).toBe(false);

    terminal.dispose();
});

test("getCellData returns underline style", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[4mUnderline\x1B[0m");

    const underlineCell = terminal.getCellData(0, 0);
    expect(underlineCell.text).toBe("U");
    expect(underlineCell.underline).toBeGreaterThan(0);

    terminal.dispose();
});

test("getCellData returns foreground palette color", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[31mRed\x1B[0m");

    const redCell = terminal.getCellData(0, 0);
    expect(redCell.text).toBe("R");
    expect(redCell.fg.type).toBe(1);
    expect(redCell.fg.paletteIdx).toBe(1);

    terminal.dispose();
});

test("getCellData returns RGB foreground color", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[38;2;255;128;64mRGB\x1B[0m");

    const rgbCell = terminal.getCellData(0, 0);
    expect(rgbCell.text).toBe("R");
    expect(rgbCell.fg.type).toBe(2);
    expect(rgbCell.fg.r).toBe(255);
    expect(rgbCell.fg.g).toBe(128);
    expect(rgbCell.fg.b).toBe(64);

    terminal.dispose();
});

test("getCellData returns background palette color", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[42mGreen BG\x1B[0m");

    const greenBgCell = terminal.getCellData(0, 0);
    expect(greenBgCell.text).toBe("G");
    expect(greenBgCell.bg.type).toBe(1);
    expect(greenBgCell.bg.paletteIdx).toBe(2);

    terminal.dispose();
});

test("getCellData returns RGB background color", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[48;2;200;100;50mBG\x1B[0m");

    const bgCell = terminal.getCellData(0, 0);
    expect(bgCell.text).toBe("B");
    expect(bgCell.bg.type).toBe(2);
    expect(bgCell.bg.r).toBe(200);
    expect(bgCell.bg.g).toBe(100);
    expect(bgCell.bg.b).toBe(50);

    terminal.dispose();
});

test("getCellData handles multiple styles combined", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[1;3;4;31mStyled\x1B[0m");

    const styledCell = terminal.getCellData(0, 0);
    expect(styledCell.text).toBe("S");
    expect(styledCell.bold).toBe(true);
    expect(styledCell.italic).toBe(true);
    expect(styledCell.underline).toBeGreaterThan(0);
    expect(styledCell.fg.type).toBe(1);
    expect(styledCell.fg.paletteIdx).toBe(1);

    terminal.dispose();
});

test("getCellData handles newlines", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("Line1\r\nLine2");

    expect(terminal.getCellData(0, 0).text).toBe("L");
    expect(terminal.getCellData(0, 4).text).toBe("1");
    expect(terminal.getCellData(1, 0).text).toBe("L");
    expect(terminal.getCellData(1, 4).text).toBe("2");

    terminal.dispose();
});

test("getCellData handles empty cells", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("A");

    expect(terminal.getCellData(0, 0).text).toBe("A");
    expect(terminal.getCellData(0, 1).text).toBe("");
    expect(terminal.getCellData(0, 10).text).toBe("");

    terminal.dispose();
});

test("getCellData with inverse style", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[7mInverse\x1B[0m");

    const inverseCell = terminal.getCellData(0, 0);
    expect(inverseCell.text).toBe("I");
    expect(inverseCell.inverse).toBe(true);

    terminal.dispose();
});

test("getCellData with faint style", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[2mFaint\x1B[0m");

    const faintCell = terminal.getCellData(0, 0);
    expect(faintCell.text).toBe("F");
    expect(faintCell.faint).toBe(true);

    terminal.dispose();
});

test("getCellData with strikethrough style", () => {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onWrite: () => {},
    });

    terminal.write("\x1B[9mStrike\x1B[0m");

    const strikeCell = terminal.getCellData(0, 0);
    expect(strikeCell.text).toBe("S");
    expect(strikeCell.strikethrough).toBe(true);

    terminal.dispose();
});
