import { native, type TerminalOptions, type Terminal } from "./bindings.js";

export type { Terminal, TerminalOptions } from "./bindings.js";

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
    };
}
