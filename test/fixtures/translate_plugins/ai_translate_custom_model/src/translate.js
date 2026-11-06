// Offline QA script: no network call. Echoes every line with a "[QA] " prefix.
function execute(input) {
  const items = input.lines.map((line) => ({ text: '[QA] ' + line }));
  return Response.success(items);
}
