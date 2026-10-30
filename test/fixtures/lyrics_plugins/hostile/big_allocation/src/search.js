// Asks for far more than the 32 MiB heap.
function execute(input) {
  console.log("before the allocation");
  var big = "x".repeat(64 * 1024 * 1024);
  return Response.success([big.length]);
}
