// The Flutter app calls these as plain HTTP endpoints (not through a
// browser), so CORS isn't strictly required — but it's added so the same
// endpoints work untouched if a Flutter Web build ever calls them too.
function applyCors(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    res.status(204).end();
    return true;
  }
  return false;
}

module.exports = {applyCors};
