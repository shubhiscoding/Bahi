import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    testTimeout: 15000, // real Postgres round-trips, not mocked
    fileParallelism: false, // all suites share one bahi_test DB — avoid cross-file races
  },
});
