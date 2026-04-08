// FFI bindings for Oxigraph WASM — RDF parsing
// Mirrors the pattern from graph-browser

export const parseQuadsImpl = (format) => (baseIri) => (input) => () => {
  const ox = globalThis.oxigraph;
  const store = new ox.Store();
  store.load(input, { format, base_iri: baseIri });

  const quads = [];
  for (const quad of store) {
    const obj = quad.object;
    const objectRecord = obj.termType === "Literal"
      ? { value: obj.value, type: "literal", datatype: obj.datatype ? obj.datatype.value : "", language: obj.language || "" }
      : { value: obj.value, type: "named", datatype: "", language: "" };

    quads.push({
      subject: quad.subject.value,
      predicate: quad.predicate.value,
      object: objectRecord
    });
  }
  return quads;
};
