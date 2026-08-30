/// Base URL for the Node/Express backend.
///
/// Currently pointed at the Vercel deployment (REST only — Socket.IO
/// live updates don't run there, see backend/api/index.ts; the app still
/// works via REST fetch-on-load, just without real-time push updates
/// until sockets are hosted somewhere that supports persistent
/// connections, e.g. the EC2 plan discussed separately).
const String backendBaseUrl = 'https://bahi-murex.vercel.app';
