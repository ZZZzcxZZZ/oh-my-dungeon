import { Injectable } from "@nestjs/common";
import type {
  ContentValidationError,
  ContentValidationReport,
} from "./campaign-sync.types";

/**
 * The 10 content block types allowed by the local compendium v1 format.
 * Mirrors `ContentBlock.fromJson` in the Flutter client: unknown block
 * types and the legacy `html` block are rejected.
 */
const ALLOWED_BLOCK_TYPES: ReadonlySet<string> = new Set([
  "heading",
  "paragraph",
  "list",
  "table",
  "quote",
  "callout",
  "image",
  "statBlock",
  "entryLink",
  "diceExpression",
]);

/**
 * Top-level fields that would turn a standalone campaign entry into a
 * package manifest, overlay, or dependency declaration. Campaign sync
 * only carries standalone JSON entries — no patches, overrides, or
 * package-level metadata.
 */
const FORBIDDEN_TOP_LEVEL_FIELDS: ReadonlySet<string> = new Set([
  "formatVersion",
  "packageId",
  "packageName",
  "version",
  "locale",
  "system",
  "entryCount",
  "baseEntryId",
  "patch",
  "patchData",
  "override",
  "overrideType",
  "derivedContentItemId",
  "dependency",
  "dependencies",
]);

/**
 * Entry-level fields that would embed overlay/patch semantics inside a
 * campaign content entry body. The entry must be a self-contained JSON
 * object (body + tags + structured), not a delta over another package.
 */
const FORBIDDEN_ENTRY_FIELDS: ReadonlySet<string> = new Set([
  "baseEntryId",
  "patch",
  "patchData",
  "override",
  "overrideType",
  "derivedContentItemId",
  "dependency",
  "dependencies",
]);

@Injectable()
export class CampaignEntryValidatorService {
  /**
   * Validates a standalone campaign content entry without writing to the
   * database. Returns a report with `valid: true` when the entry passes
   * all checks, or `valid: false` with a list of JSON-path-keyed errors.
   */
  validate(input: {
    type?: unknown;
    slug?: unknown;
    name?: unknown;
    entry?: unknown;
    [key: string]: unknown;
  }): ContentValidationReport {
    const errors: ContentValidationError[] = [];

    // Check forbidden top-level fields first so callers see them even
    // when the required-field checks also fail.
    for (const key of Object.keys(input)) {
      if (FORBIDDEN_TOP_LEVEL_FIELDS.has(key)) {
        errors.push({
          path: `$.${key}`,
          message: `Field "${key}" is forbidden in a campaign content entry`,
        });
      }
    }

    if (!isNonEmptyString(input.type)) {
      errors.push({ path: "$.type", message: "type must be a non-empty string" });
    }
    if (!isNonEmptyString(input.slug)) {
      errors.push({ path: "$.slug", message: "slug must be a non-empty string" });
    }
    if (!isNonEmptyString(input.name)) {
      errors.push({ path: "$.name", message: "name must be a non-empty string" });
    }
    if (!isObject(input.entry)) {
      errors.push({ path: "$.entry", message: "entry must be an object" });
    } else {
      this.validateEntry(input.entry, errors);
    }

    return { valid: errors.length === 0, errors };
  }

  private validateEntry(
    entry: Record<string, unknown>,
    errors: ContentValidationError[],
  ): void {
    for (const key of Object.keys(entry)) {
      if (FORBIDDEN_ENTRY_FIELDS.has(key)) {
        errors.push({
          path: `$.entry.${key}`,
          message: `Field "${key}" is forbidden inside a campaign content entry`,
        });
      }
    }

    const body = entry.body;
    if (body !== undefined) {
      if (!Array.isArray(body)) {
        errors.push({
          path: "$.entry.body",
          message: "body must be an array of content blocks",
        });
        return;
      }
      body.forEach((block, index) => {
        this.validateBlock(block, index, errors);
      });
    }

    if (entry.tags !== undefined && !Array.isArray(entry.tags)) {
      errors.push({
        path: "$.entry.tags",
        message: "tags must be an array of strings",
      });
    }
  }

  private validateBlock(
    block: unknown,
    index: number,
    errors: ContentValidationError[],
  ): void {
    if (!isObject(block)) {
      errors.push({
        path: `$.entry.body[${index}]`,
        message: "content block must be an object",
      });
      return;
    }
    const type = block.type;
    if (typeof type !== "string" || !ALLOWED_BLOCK_TYPES.has(type)) {
      errors.push({
        path: `$.entry.body[${index}].type`,
        message: `Unsupported content block type: ${String(type)}`,
      });
    }
  }
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
