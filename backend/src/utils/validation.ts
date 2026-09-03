/**
 * Small, shared input-sanity checks — used across items/buyers/bills so a
 * negative price, a zero/negative quantity, etc. can never sneak into a
 * write path. Each returns a plain boolean; routes decide the specific
 * error code/message (kept there so each 400 response stays specific and
 * easy to assert on in tests, per Phase 8 §A0/§H).
 */

export function isFiniteNonNegativeNumber(value: unknown): boolean {
  const n = Number(value);
  return Number.isFinite(n) && n >= 0;
}

export function isPositiveInteger(value: unknown): boolean {
  const n = Number(value);
  return Number.isInteger(n) && n > 0;
}

export function isNonNegativeInteger(value: unknown): boolean {
  const n = Number(value);
  return Number.isInteger(n) && n >= 0;
}
