const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

const TYPES = new Set(["nearby_search", "nearby_category", "games_filter", "plan_created"]);

/** Keep text short so a bad client can't fill the database. */
function text(value, max) {
  return typeof value === "string" ? value.slice(0, max) : null;
}

/** Keep only up to 20 simple fields (text, number, true/false). */
function simpleMap(value) {
  const out = {};
  if (!value || typeof value !== "object") return out;
  for (const [key, v] of Object.entries(value).slice(0, 20)) {
    if (["string", "number", "boolean"].includes(typeof v)) {
      out[key.slice(0, 40)] = typeof v === "string" ? v.slice(0, 200) : v;
    }
  }
  return out;
}

/** The caller's IP address, as seen by Google's front end. */
function callerIp(rawRequest) {
  const forwarded = rawRequest.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) {
    return forwarded.split(",")[0].trim();
  }
  return rawRequest.ip || null;
}

/**
 * Saves one search to the search_logs collection with the caller's IP address
 * and the server's time.
 */
exports.logSearch = onCall({ region: "us-central1", cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const data = request.data || {};
  if (!TYPES.has(data.type)) {
    throw new HttpsError("invalid-argument", "Unknown search type.");
  }

  await getFirestore().collection("search_logs").add({
    uid: request.auth.uid,
    type: data.type,
    query: text(data.query, 200),
    filters: simpleMap(data.filters),
    device: simpleMap(data.device),
    appVersion: text(data.appVersion, 40),
    ip: callerIp(request.rawRequest),
    createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});
