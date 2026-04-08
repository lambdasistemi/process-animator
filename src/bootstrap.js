import * as oxigraph from "oxigraph/web.js";
import wasmBytes from "oxigraph/web_bg.wasm";

// Initialize Oxigraph WASM synchronously from the inlined binary,
// then expose the initialized module on globalThis for the PureScript FFI.
oxigraph.initSync({ module: new WebAssembly.Module(wasmBytes) });
globalThis.oxigraph = oxigraph;
