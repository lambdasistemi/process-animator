export const fetchText = (url) => () =>
  fetch(url).then((r) => {
    if (!r.ok) throw new Error(`HTTP ${r.status}: ${r.statusText}`);
    return r.text();
  });
