// Initialize Oxigraph WASM for browser usage
import oxigraphInit, * as oxigraph from "oxigraph/web.js";
import oxigraphWasm from "oxigraph/web_bg.wasm";

// Initialize WASM synchronously with inlined binary
oxigraphInit(oxigraphWasm);

// Expose on globalThis for FFI access
globalThis.oxigraph = oxigraph;
