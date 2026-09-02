/// Base URL for the Node/Express backend.
///
/// Pointed at the AWS EC2 deployment — moved off Vercel due to
/// serverless cold-start latency. This also restores real-time
/// Socket.IO updates (Vercel only ran the REST-only api/index.ts subset
/// since serverless functions can't hold persistent WebSocket
/// connections — EC2 runs the full src/index.ts server, sockets included).
///
/// Plain HTTP for now (no domain yet — raw IP can't get a Let's Encrypt
/// cert, which requires domain validation). Move to HTTPS via a domain +
/// nginx + certbot once one is available.
const String backendBaseUrl = 'http://13.201.193.198:4000';

// Local dev override (Dockerized Postgres + npm run dev:local) — swap the
// line above for this one when testing locally, never commit it swapped:
// const String backendBaseUrl = 'http://localhost:4000';

/// True only while pointed at a local dev backend — gates dev-only UI
/// (e.g. the Team screen's owner/member test-role switcher) that must
/// never appear in a build pointed at prod.
bool get isLocalBackend =>
    backendBaseUrl.contains('localhost') || backendBaseUrl.contains('127.0.0.1');
