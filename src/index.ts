import { native, type TerminalOptions, type Terminal } from "./bindings.js";

export type {
    Terminal,
    TerminalOptions,
    ScreenDimensions,
    ColorInfo,
    CellData,
} from "./bindings.js";

const textEncoder = new TextEncoder();

export function createTerminal(options: TerminalOptions): Terminal {
    const nativeTerminal = native.createTerminal(options);

    return {
        write(data: string | Uint8Array): void {
            const bytes =
                typeof data === "string" ? textEncoder.encode(data) : data;
            nativeTerminal.write(bytes);
        },
        dispose(): void {
            nativeTerminal.dispose();
        },
        getScreenDimensions() {
            return nativeTerminal.getScreenDimensions();
        },
        getCellData(row: number, col: number) {
            return nativeTerminal.getCellData(row, col);
        },
        getRow(row: number) {
            return nativeTerminal.getRow(row);
        },
        getRegion(
            startRow: number,
            startCol: number,
            endRow: number,
            endCol: number,
        ) {
            return nativeTerminal.getRegion(startRow, startCol, endRow, endCol);
        },
        getAllCells() {
            return nativeTerminal.getAllCells();
        },
    };
}
