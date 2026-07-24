import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    // Plain JS seed so production runtime (no ts-node) can run it.
    seed: 'node prisma/seed.js',
  },
});
