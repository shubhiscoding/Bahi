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
  // Only ever true when running against .env.local (local Docker
  // Postgres) — never set in the real .env / EC2 deploy secrets. Gates
  // the /dev/* routes (see routes/dev.routes.ts), which let a real,
  // already-signed-in user flip their own role on the seeded dev
  // business for testing, without any auth bypass.
  devMode: process.env.DEV_MODE === 'true',
};
