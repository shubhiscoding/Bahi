import dotenv from 'dotenv';

dotenv.config();

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

export const env = {
  databaseUrl: required('DATABASE_URL'),
  // Supabase project uses asymmetric JWT signing (ES256) — verified via
  // JWKS, not a shared secret. See middleware/auth.ts.
  supabaseJwksUrl: required('SUPABASE_JWKS_URL'),
  port: Number(process.env.PORT ?? 4000),
};
