// A call may send 10 requests; the 11th throws TooManyRequestsError.
function execute(input) {
  for (var i = 0; i < 11; i++) {
    console.log("fetch " + i);
    fetch("https://lrclib.net/api/search", { queries: { q: "n" + i } });
  }
  return Response.success([]);
}
