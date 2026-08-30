import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
import { env } from './env';

export interface SupabaseJwtPayload {
  sub: string;
  email?: string;
  user_metadata?: {
    full_name?: string;
    name?: string;
  };
}

// Fetches and caches signing keys from Supabase's JWKS endpoint
// (Settings → API → Discovery URL). Keys are cached and auto-refetched
// if a request comes in with an unrecognized `kid`.
const client = jwksClient({
  jwksUri: env.supabaseJwksUrl,
  cache: true,
  rateLimit: true,
});

function getKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
  if (!header.kid) {
    return callback(new Error('Missing kid in token header'));
  }
  client.getSigningKey(header.kid, (err, key) => {
    if (err) return callback(err);
    callback(null, key?.getPublicKey());
  });
}

/** Verifies a Supabase-issued JWT against the project's JWKS. */
export function verifySupabaseJwt(token: string): Promise<SupabaseJwtPayload> {
  return new Promise((resolve, reject) => {
    jwt.verify(token, getKey, { algorithms: ['ES256'] }, (err, decoded) => {
      if (err || !decoded) return reject(err ?? new Error('Invalid token'));
      resolve(decoded as SupabaseJwtPayload);
    });
  });
}
