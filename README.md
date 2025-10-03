# possess

A TypeScript library with a Zig N-API addon that integrates [Ghostty](https://github.com/ghostty-org/ghostty)'s VT terminal emulator module.

## Features

- Written in Zig for high performance
- Uses N-API for compatibility with both Bun and Node.js
- Integrates Ghostty's virtual terminal emulation library

## Installation

```bash
bun install
```

## Building

```bash
bun run build
```

This will:
1. Build the Zig native addon with Ghostty integration
2. Compile TypeScript to JavaScript
3. Generate TypeScript declarations

## Usage

```typescript
import { example } from "possess";

console.log(example()); // "Hello from Zig!"
```

## Examples

Run the example with Bun (uses TypeScript directly):
```bash
bun run example
```

Run the example with Node.js (builds first, then runs compiled JS):
```bash
bun run example:node
```

Or run manually:
```bash
# With Bun
bun examples/basic.ts

# With Node.js (after building)
bun run build
node examples/basic-node.js
```

## Development

### Project Structure

```
possess/
├── native/              # Zig N-API addon
│   ├── src/
│   │   ├── napi.zig    # N-API bindings
│   │   └── lib.zig     # Library wrapper
│   ├── build.zig       # Zig build configuration
│   └── build.zig.zon   # Zig dependencies (Ghostty)
├── lib/                # Compiled .node addons (per platform)
├── src/
│   ├── bindings.ts     # Load .node addon
│   └── index.ts        # Public TypeScript API
├── examples/
│   └── basic.ts        # Usage example
└── scripts/
    └── build-native.sh # Build script
```

### Building Native Addon Only

```bash
bun run build:native
```

### Type Checking

```bash
bun run typecheck
```

## Requirements

- Zig 0.15.1 or later
- Node.js 18+ or Bun
- C++ compiler (for Ghostty dependencies)

## License

MIT
