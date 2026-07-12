import { BadRequestException, Injectable } from "@nestjs/common";
import type {
  ContentPackageImport,
  ContentValidationResult,
} from "./content.types";

const SUPPORTED_TYPES = new Set([
  "spell",
  "item",
  "equipment",
  "species",
  "class",
  "background",
  "feat",
  "feature",
  "monster",
  "condition",
]);

@Injectable()
export class ContentPackageValidatorService {
  validate(input: unknown): ContentValidationResult {
    const errors: string[] = [];
    if (!isRecord(input)) {
      return {
        valid: false,
        errors: ["Package payload is required"],
      };
    }

    if (!isNonEmptyString(input.name)) {
      errors.push("Package name is required");
    }
    if (!isNonEmptyString(input.version)) {
      errors.push("Package version is required");
    }
    if (!Array.isArray(input.items) || input.items.length === 0) {
      errors.push("Package must contain at least one item");
    }

    const seenKeys = new Set<string>();
    if (Array.isArray(input.items)) {
      input.items.forEach((item, index) => {
        if (!isRecord(item)) {
          errors.push(`items[${index}] must be an object`);
          return;
        }
        if (!isNonEmptyString(item.type) || !SUPPORTED_TYPES.has(item.type)) {
          errors.push(`items[${index}].type is not supported`);
        }
        if (!isNonEmptyString(item.slug)) {
          errors.push(`items[${index}].slug is required`);
        }
        if (!isNonEmptyString(item.name)) {
          errors.push(`items[${index}].name is required`);
        }
        if (isNonEmptyString(item.type) && isNonEmptyString(item.slug)) {
          const key = `${item.type}:${item.slug}`;
          if (seenKeys.has(key)) {
            errors.push(`Duplicate item key ${key}`);
          }
          seenKeys.add(key);
        }
      });
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  }

  assertValid(input: unknown): asserts input is ContentPackageImport {
    const result = this.validate(input);
    if (!result.valid) {
      throw new BadRequestException({
        message: "Content package validation failed",
        errors: result.errors,
      });
    }
  }
}

function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}
