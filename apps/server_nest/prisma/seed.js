// Server seed: ensure a ServerSetting row exists. Idempotent.
// Plain JS (no ts-node required) so production images without devDependencies
// can still run `prisma db seed`.
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

async function main() {
  // The compendium is local-first and empty by default. The seed only ensures
  // a server settings row exists with registration enabled; it never creates
  // ContentPackage or ContentItem rows. Users import their own JSON or
  // `.dndpack` packages locally on the client.
  const existing = await prisma.serverSetting.findFirst();
  if (!existing) {
    await prisma.serverSetting.create({
      data: { registrationEnabled: true },
    });
  }
  console.log("Server settings initialized.");
}

main()
  .catch((error) => {
    console.error("Seed failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
