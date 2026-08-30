/// Base URL for the Node/Express backend.
///
/// - Android emulator talking to a backend running on your own machine:
///   use 10.0.2.2 (special alias to the host machine from inside the emulator).
/// - Physical device on the same network as your dev machine:
///   use your machine's LAN IP (e.g. 192.168.x.x) instead of 10.0.2.2.
/// - Deployed backend: replace with the real hosted URL.
const String backendBaseUrl = 'http://10.0.2.2:4000';
