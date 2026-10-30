// load() only reaches files of src/ with a plain name.
function execute(input) {
  console.log("before the load");
  load("../x.js");
  return Response.success([]);
}
