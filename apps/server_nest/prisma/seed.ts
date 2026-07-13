import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main(): Promise<void> {
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
