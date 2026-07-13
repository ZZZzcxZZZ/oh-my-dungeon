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

/**
 * 导入内置资料库种子数据。
 *
 * 优先从 private-imports/ 目录读取用户本地提取的 PHB PDF 索引
 * （517 项：种族/职业/背景/专长/装备/法术），该文件由
 * `python scripts/generate_phb_private_index.py` 生成，不提交到 git。
 *
 * 如果私有索引不存在，回退到仓库内的 SRD 5.1 基础资料。
 */
function resolveSeedPath(): { path: string; label: string } | null {
  const candidates = [
    {
      path: path.resolve(__dirname, "../../../private-imports/phb-2024-index.content.private.json"),
      label: "PHB 2024 PDF 索引",
    },
    {
      path: path.join(__dirname, "srd-5.1-seed.json"),
      label: "SRD 5.1 基础资料",
    },
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate.path)) {
      return candidate;
    }
  }
  return null;
}

async function main(): Promise<void> {
  const resolved = resolveSeedPath();
  if (!resolved) {
    console.log("No seed data found. Skipping.");
    return;
  }

  const raw = fs.readFileSync(resolved.path, "utf-8");
  const seed: SeedPackage = JSON.parse(raw);

  // 内置化：覆盖私有标记，让包名体现"内置资料"。
  if (resolved.label.startsWith("PHB")) {
    seed.name = "玩家手册 2024 内置资料";
    seed.version = "2024.0.0";
  }

  // 替换已有的 system 包：先删旧条目和包，再导入新的。
  const existing = await prisma.contentPackage.findMany({
    where: { scope: "system" },
    select: { id: true },
  });
  if (existing.length > 0) {
    await prisma.contentItem.deleteMany({
      where: { packageId: { in: existing.map((p) => p.id) } },
    });
    await prisma.contentPackage.deleteMany({
      where: { scope: "system" },
    });
    console.log(`Removed ${existing.length} old system package(s).`);
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
    `Seeded ${resolved.label}: package ${created.id} with ${created.items.length} items.`,
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
