// The script hides the failure behind an empty answer. The app must still
// treat the run as failed and never store "no lyrics".
function execute(input) {
  try {
    fetch("https://lrclib.net/down");
  } catch (e) {
    console.log("fetch failed: " + e.name);
  }
  return Response.success([]);
}
