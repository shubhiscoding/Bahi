const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

/** Generate a random 8-character invite code (uppercase alphanumeric). */
export function generateInviteCode(): string {
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += CHARS[Math.floor(Math.random() * CHARS.length)];
  }
  return code;
}
