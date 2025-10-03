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

interface NativeBindings {
    example(): string;
    // TODO: Add your function signatures here
}

export const native: NativeBindings = require(addonPath);
