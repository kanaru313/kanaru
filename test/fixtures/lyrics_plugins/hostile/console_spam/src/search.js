// 20000 lines of 1000 characters. The call keeps 50 lines of 500 characters.
function execute(input) {
  for (var i = 0; i < 20000; i++) {
    console.log("line " + i + " " + "x".repeat(1000));
  }
  return Response.success([]);
}
