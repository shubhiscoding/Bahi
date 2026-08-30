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
  supabaseJwtSecret: required('SUPABASE_JWT_SECRET'),
  port: Number(process.env.PORT ?? 4000),
};
