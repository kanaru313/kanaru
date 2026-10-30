// Overflows the JS stack.
function down(n) {
  return 1 + down(n + 1);
}
function execute(input) {
  console.log("before the recursion");
  return Response.success([down(0)]);
}
