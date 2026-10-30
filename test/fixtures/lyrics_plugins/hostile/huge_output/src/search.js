// The output limit is 2 MiB of JSON.
function execute(input) {
  console.log("before the answer");
  return Response.success(["x".repeat(3 * 1024 * 1024)]);
}
