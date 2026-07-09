import { BadRequestException } from "@nestjs/common";
import { ContentPackageValidatorService } from "./content-package-validator.service";

describe("ContentPackageValidatorService", () => {
  let validator: ContentPackageValidatorService;

  beforeEach(() => {
    validator = new ContentPackageValidatorService();
  });

  it("accepts a valid package", () => {
    const result = validator.validate({
      name: "Basic Spells",
      version: "1.0.0",
      schemaVersion: 1,
      locale: "zh-CN",
      items: [
        {
          type: "spell",
          slug: "fire-bolt",
          name: "Fire Bolt",
          description: "A mote of fire.",
          structured: { level: 0 },
          tags: ["cantrip"],
          sourceLabel: "SRD",
        },
      ],
    });

    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it("reports missing package metadata", () => {
    const result = validator.validate({
      version: "",
      items: [],
    });

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("Package name is required");
    expect(result.errors).toContain("Package version is required");
    expect(result.errors).toContain("Package must contain at least one item");
  });

  it("reports unsupported item types", () => {
    const result = validator.validate({
      name: "Bad Package",
      version: "1.0.0",
      items: [
        {
          type: "class",
          slug: "fighter",
          name: "Fighter",
        },
      ],
    });

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("items[0].type is not supported");
  });

  it("reports duplicated type and slug in one package", () => {
    const result = validator.validate({
      name: "Duplicate Package",
      version: "1.0.0",
      items: [
        { type: "spell", slug: "shield", name: "Shield" },
        { type: "spell", slug: "shield", name: "Shield Copy" },
      ],
    });

    expect(result.valid).toBe(false);
    expect(result.errors).toContain("Duplicate item key spell:shield");
  });

  it("throws BadRequestException for invalid imports", () => {
    expect(() =>
      validator.assertValid({ name: "Empty", version: "1", items: [] }),
    ).toThrow(BadRequestException);
  });
});
