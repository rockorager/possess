import { bench, run } from "mitata";
import { createTerminal } from "./index.js";

// Setup terminal with some content
function setupTerminal() {
    const terminal = createTerminal({
        cols: 80,
        rows: 24,
        onData: () => {},
    });

    // Fill with styled content
    for (let row = 0; row < 24; row++) {
        terminal.write(
            `\x1B[${31 + (row % 7)}m\x1B[1mRow ${row.toString().padStart(2, "0")}: `,
        );
        terminal.write("A".repeat(60));
        terminal.write("\x1B[0m");
        if (row < 23) terminal.write("\r\n");
    }

    return terminal;
}

// Benchmark: Get a single row using individual getCell calls
bench("Individual getCell - single row (80 cells)", () => {
    const terminal = setupTerminal();
    const row = 10;
    const _cells = [];

    for (let col = 0; col < 80; col++) {
        _cells.push(terminal.getCell(row, col));
    }

    terminal.dispose();
});

// Benchmark: Get a single row using bulk getRow
bench("Bulk getRow - single row (80 cells)", () => {
    const terminal = setupTerminal();
    const _cells = terminal.getRow(10);
    terminal.dispose();
});

// Benchmark: Get a 10x10 region using individual getCell calls
bench("Individual getCell - 10x10 region (100 cells)", () => {
    const terminal = setupTerminal();
    const _cells = [];

    for (let row = 5; row < 15; row++) {
        const rowCells = [];
        for (let col = 10; col < 20; col++) {
            rowCells.push(terminal.getCell(row, col));
        }
        _cells.push(rowCells);
    }

    terminal.dispose();
});

// Benchmark: Get all cells using individual getCell calls
bench("Individual getCell - all cells (80x24 = 1920 cells)", () => {
    const terminal = setupTerminal();
    const _cells = [];

    for (let row = 0; row < 24; row++) {
        const rowCells = [];
        for (let col = 0; col < 80; col++) {
            rowCells.push(terminal.getCell(row, col));
        }
        _cells.push(rowCells);
    }

    terminal.dispose();
});

// Benchmark: Get all cells using bulk getAllCells
bench("Bulk getAllCells - all cells (80x24 = 1920 cells)", () => {
    const terminal = setupTerminal();
    const _cells = terminal.getAllCells();
    terminal.dispose();
});

// Benchmark: Get multiple rows individually
bench("Individual getCell - 5 rows (400 cells)", () => {
    const terminal = setupTerminal();
    const _cells = [];

    for (let row = 10; row < 15; row++) {
        const rowCells = [];
        for (let col = 0; col < 80; col++) {
            rowCells.push(terminal.getCell(row, col));
        }
        _cells.push(rowCells);
    }

    terminal.dispose();
});

// Benchmark: Get multiple rows using bulk getRow
bench("Bulk getRow - 5 rows (400 cells)", () => {
    const terminal = setupTerminal();
    const _cells = [];

    for (let row = 10; row < 15; row++) {
        _cells.push(terminal.getRow(row));
    }

    terminal.dispose();
});

await run();
