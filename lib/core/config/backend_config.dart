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

// Local dev override (Dockerized Postgres + npm run dev:local) — swap
// back to the line above before committing/shipping prod-ready changes.
// Use 'http://localhost:4000' for an emulator, or your machine's LAN IP
// (e.g. 'http://192.168.1.23:4000') when testing on a physical device.
// const String backendBaseUrl = 'http://localhost:4000';

/// True only while pointed at a local dev backend — gates dev-only UI
/// (e.g. the Team screen's owner/member test-role switcher) that must
/// never appear in a build pointed at prod.
///
/// Also matches private-network IPs (10.x, 172.16-31.x, 192.168.x) since
/// testing on a physical phone points here at the dev machine's LAN IP
/// instead of localhost/127.0.0.1 (a real device can't resolve those to
/// the dev machine). Prod always points at a public IP/domain, so this
/// stays false there.
bool get isLocalBackend =>
    backendBaseUrl.contains('localhost') ||
    backendBaseUrl.contains('127.0.0.1') ||
    RegExp(r'://(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)').hasMatch(backendBaseUrl);
