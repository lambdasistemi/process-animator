export const parseQuadsImpl = (format) => (baseIri) => (input) => () =>
  globalThis.oxigraph.parse(input, { format, base_iri: baseIri }).map((quad) => ({
    subject: quad.subject.value,
    predicate: quad.predicate.value,
    object: {
      termType: quad.object.termType,
      value: quad.object.value,
      datatype:
        quad.object.termType === "Literal" && quad.object.datatype
          ? quad.object.datatype.value
          : "",
      language:
        quad.object.termType === "Literal" && quad.object.language
          ? quad.object.language
          : "",
    },
  }));
