import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { platform, arch } from "node:os";

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));

function getPlatformPath(): string {
    const platformName = platform();
    const archName = arch();
    const platformMap: Record<string, string> = {
        "darwin-arm64": "darwin-arm64",
        "darwin-x64": "darwin-x64",
        "linux-x64": "linux-x64",
        "win32-x64": "win32-x64",
    };

    const key = `${platformName}-${archName}`;
    const platformPath = platformMap[key];

    if (!platformPath) {
        throw new Error(`Unsupported platform: ${key}`);
    }

    return platformPath;
}

const addonPath = join(
    __dirname,
    "..",
    "lib",
    getPlatformPath(),
    "possess.node",
);

export interface ScreenDimensions {
    rows: number;
    cols: number;
}

export interface ColorInfo {
    type: 0 | 1 | 2; // 0 = none, 1 = palette, 2 = rgb
    paletteIdx?: number;
    r?: number;
    g?: number;
    b?: number;
}

export interface CellData {
    text: string;
    wide: number; // 0 = narrow, 1 = wide, 2 = spacer_tail, 3 = spacer_head
    fg: ColorInfo;
    bg: ColorInfo;
    bold: boolean;
    italic: boolean;
    faint: boolean;
    inverse: boolean;
    invisible: boolean;
    strikethrough: boolean;
    underline: number; // 0 = none, 1 = single, 2 = double, etc.
}

export interface NativeTerminal {
    write(data: Uint8Array): void;
    dispose(): void;
    getScreenDimensions(): ScreenDimensions;
    getCell(row: number, col: number): CellData;
    getRow(row: number): CellData[];
    getAllCells(): CellData[][];
    clearDirty(): void;
    hasAnyDirtyRows(): boolean;
    getMode(mode: number): boolean;
    isSyncModeEnabled(): boolean;
    getRowIfDirty(row: number): CellData[] | null;
}

export interface Terminal {
    write(data: string | Uint8Array): void;
    dispose(): void;
    getScreenDimensions(): ScreenDimensions;
    getCell(row: number, col: number): CellData;
    getRow(row: number): CellData[];
    getAllCells(): CellData[][];
    clearDirty(): void;
    hasAnyDirtyRows(): boolean;
    getMode(mode: number): boolean;
    isSyncModeEnabled(): boolean;
    getRowIfDirty(row: number): CellData[] | null;
}

export interface TerminalOptions {
    cols: number;
    rows: number;
    onData: (data: Uint8Array) => void;
    onQueueRender?: () => void;
}

interface NativeBindings {
    createTerminal(options: TerminalOptions): NativeTerminal;
}

export const native: NativeBindings = require(addonPath);
