import { PrismaClient } from "@prisma/client";
import * as path from "path";
import * as fs from "fs";

const prisma = new PrismaClient();

interface SeedItem {
  type: string;
  slug: string;
  name: string;
  description?: string;
  structured?: Record<string, unknown>;
  tags?: string[];
  sourceLabel?: string;
  schemaVersion?: number;
}

interface SeedPackage {
  name: string;
  version: string;
  schemaVersion?: number;
  locale?: string;
  items: SeedItem[];
}

async function main(): Promise<void> {
  const seedPath = path.join(__dirname, "srd-5.1-seed.json");
  const raw = fs.readFileSync(seedPath, "utf-8");
  const seed: SeedPackage = JSON.parse(raw);

  const existing = await prisma.contentPackage.findFirst({
    where: { scope: "system", name: seed.name, version: seed.version },
    select: { id: true },
  });
  if (existing) {
    console.log(`SRD seed already present (${existing.id}), skipping.`);
    return;
  }

  const created = await prisma.contentPackage.create({
    data: {
      scope: "system",
      ownerUserId: null,
      campaignId: null,
      name: seed.name,
      version: seed.version,
      schemaVersion: seed.schemaVersion ?? 1,
      locale: seed.locale ?? "zh-CN",
      status: "active",
      createdBy: "system",
      items: {
        create: seed.items.map((item) => ({
          type: item.type,
          slug: item.slug,
          name: item.name,
          description: item.description ?? "",
          structured: (item.structured ?? {}) as any,
          tags: (item.tags ?? []) as any,
          sourceLabel: item.sourceLabel ?? "",
          schemaVersion: item.schemaVersion ?? seed.schemaVersion ?? 1,
        })),
      },
    },
    include: { items: true },
  });

  console.log(
    `Seeded SRD package ${created.id} with ${created.items.length} items.`,
  );
}

main()
  .catch((error) => {
    console.error("Seed failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
