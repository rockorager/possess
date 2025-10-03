import { createTerminal } from "../src/index.js";

console.log("Creating terminal...");

const writtenData: Uint8Array[] = [];

const terminal = createTerminal({
    cols: 80,
    rows: 24,
    onData: (data) => {
        console.log("Terminal wants to write:", data);
        writtenData.push(data);
    },
});

console.log("Terminal created!");

// Send some input to the terminal
console.log("\nSending 'hello' to terminal...");
terminal.write("hello");

// Send a device status report request (ESC [ 5 n)
console.log("\nSending device status report request...");
terminal.write("\x1B[5n");

// Wait a bit to see if callback is called
setTimeout(() => {
    console.log("\nData written by terminal:");
    for (const data of writtenData) {
        console.log("  ", Buffer.from(data).toString("hex"));
        console.log("  ", JSON.stringify(Buffer.from(data).toString()));
    }

    // Send cursor position report request (ESC [ 6 n)
    console.log("\nSending cursor position request...");
    terminal.write("\x1B[6n");

    setTimeout(() => {
        console.log("\nAll data written by terminal:");
        for (const data of writtenData) {
            console.log("  ", Buffer.from(data).toString("hex"));
            console.log("  ", JSON.stringify(Buffer.from(data).toString()));
        }

        console.log("\nCleaning up...");
        terminal.dispose();
        console.log("Done!");
    }, 100);
}, 100);
