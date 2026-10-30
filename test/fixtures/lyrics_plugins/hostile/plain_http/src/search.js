// Only https is allowed, even for a declared host.
function execute(input) {
  console.log("before the fetch");
  fetch("http://lrclib.net/api/search", { queries: { q: input.title } });
  return Response.success([]);
}
