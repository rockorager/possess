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
        getCell(row: number, col: number) {
            return nativeTerminal.getCell(row, col);
        },
        getRow(row: number) {
            return nativeTerminal.getRow(row);
        },
        getAllCells() {
            return nativeTerminal.getAllCells();
        },
        clearDirty() {
            nativeTerminal.clearDirty();
        },
        hasAnyDirtyRows() {
            return nativeTerminal.hasAnyDirtyRows();
        },
        getMode(mode: number) {
            return nativeTerminal.getMode(mode);
        },
        isSyncModeEnabled() {
            return nativeTerminal.isSyncModeEnabled();
        },
        getRowIfDirty(row: number) {
            return nativeTerminal.getRowIfDirty(row);
        },
    };
}
