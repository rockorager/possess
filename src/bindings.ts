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

export interface NativeTerminal {
    write(data: Uint8Array): void;
    dispose(): void;
}

export interface Terminal {
    write(data: string | Uint8Array): void;
    dispose(): void;
}

export interface TerminalOptions {
    cols: number;
    rows: number;
    onWrite: (data: Uint8Array) => void;
}

interface NativeBindings {
    createTerminal(options: TerminalOptions): NativeTerminal;
}

export const native: NativeBindings = require(addonPath);
