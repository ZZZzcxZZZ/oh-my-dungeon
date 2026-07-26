export const CHARACTER_STATE_SCHEMA_VERSION = 2;

export interface HitPoints {
  current: number;
  maximum: number;
  temporary: number;
}

export interface DeathSaves {
  successes: number;
  failures: number;
}

export interface CharacterResource {
  id: string;
  name: string;
  current: number;
  maximum: number;
  restoreOn: 'shortRest' | 'longRest' | 'none';
  sourceRef: string | null;
  custom: boolean;
}

export interface CharacterCondition {
  id: string;
  type: string;
  source: { type: string; id: string | null } | null;
  duration: { unit: string; value: number } | null;
  remaining: number | null;
  removable: boolean;
  metadata: Record<string, unknown>;
}

export interface CharacterItem {
  id: string;
  templateRef: string | null;
  name: string;
  quantity: number;
  equipped: boolean;
  attuned: boolean;
  instanceData: Record<string, unknown>;
}

export interface CharacterState {
  schemaVersion: 2;
  hitPoints: HitPoints;
  deathSaves: DeathSaves;
  resources: CharacterResource[];
  conditions: CharacterCondition[];
  items: CharacterItem[];
  extensions: Record<string, unknown>;
}

export function parseCharacterState(value: unknown): CharacterState {
  const root = record(value);
  const runtime = record(root.runtime);
  const hitPoints = parseHitPoints(root, runtime);
  return {
    schemaVersion: CHARACTER_STATE_SCHEMA_VERSION,
    hitPoints,
    deathSaves: parseDeathSaves(root.deathSaves ?? runtime.deathSaves),
    resources: array(root.resources).map(parseResource).filter(isPresent),
    conditions: array(root.conditions ?? runtime.conditions)
      .map(parseCondition)
      .filter(isPresent),
    items: array(root.items ?? root.inventory).map(parseItem).filter(isPresent),
    extensions: parseExtensions(root.extensions),
  };
}

export function serializeCharacterState(
  state: CharacterState,
): Record<string, unknown> {
  return {
    schemaVersion: CHARACTER_STATE_SCHEMA_VERSION,
    hitPoints: { ...state.hitPoints },
    deathSaves: { ...state.deathSaves },
    resources: state.resources.map((item) => ({ ...item })),
    conditions: state.conditions.map((item) => ({
      ...item,
      source: item.source ? { ...item.source } : null,
      duration: item.duration ? { ...item.duration } : null,
      metadata: { ...item.metadata },
    })),
    items: state.items.map((item) => ({
      ...item,
      instanceData: { ...item.instanceData },
    })),
    extensions: { ...state.extensions },
  };
}

function parseHitPoints(
  root: Record<string, unknown>,
  runtime: Record<string, unknown>,
): HitPoints {
  const hp = record(root.hitPoints);
  let maximum = integer(hp.maximum ?? root.maxHp, 0);
  let current = integer(hp.current ?? root.currentHp ?? runtime.currentHp, 0);
  if (typeof root.hp === 'string') {
    const match = /^(\d+)\s*\/\s*(\d+)$/.exec(root.hp);
    if (match) {
      current = Number(match[1]);
      maximum = Number(match[2]);
    }
  }
  maximum = Math.max(0, maximum);
  return {
    current: clamp(current, 0, maximum),
    maximum,
    temporary: Math.max(
      0,
      integer(hp.temporary ?? runtime.temporaryHp, 0),
    ),
  };
}

function parseDeathSaves(value: unknown): DeathSaves {
  const saves = record(value);
  return {
    successes: clamp(integer(saves.successes, 0), 0, 3),
    failures: clamp(integer(saves.failures, 0), 0, 3),
  };
}

function parseResource(value: unknown): CharacterResource | null {
  const item = record(value);
  const id = text(item.id);
  const name = text(item.name);
  if (!id || !name) return null;
  const maximum = Math.max(0, integer(item.maximum, 0));
  const restoreOn =
    item.restoreOn === 'shortRest' ||
    item.restoreOn === 'longRest' ||
    item.restoreOn === 'none'
      ? item.restoreOn
      : 'longRest';
  return {
    id,
    name,
    current: clamp(integer(item.current, maximum), 0, maximum),
    maximum,
    restoreOn,
    sourceRef: text(item.sourceRef) || null,
    custom: item.custom === true,
  };
}

function parseCondition(value: unknown): CharacterCondition | null {
  if (typeof value === 'string') {
    return {
      id: value,
      type: value,
      source: null,
      duration: null,
      remaining: null,
      removable: true,
      metadata: {},
    };
  }
  const item = record(value);
  const id = text(item.id);
  const type = text(item.type);
  if (!id || !type) return null;
  const source = record(item.source);
  const duration = record(item.duration);
  return {
    id,
    type,
    source: text(source.type)
      ? { type: text(source.type), id: text(source.id) || null }
      : null,
    duration: text(duration.unit)
      ? {
          unit: text(duration.unit),
          value: Math.max(0, integer(duration.value, 0)),
        }
      : null,
    remaining:
      item.remaining === null || item.remaining === undefined
        ? null
        : Math.max(0, integer(item.remaining, 0)),
    removable: item.removable !== false,
    metadata: record(item.metadata),
  };
}

function parseItem(value: unknown): CharacterItem | null {
  const item = record(value);
  const id = text(item.id);
  const name = text(item.name);
  if (!id || !name) return null;
  return {
    id,
    templateRef: text(item.templateRef) || null,
    name,
    quantity: Math.max(0, integer(item.quantity, 1)),
    equipped: item.equipped === true,
    attuned: item.attuned === true,
    instanceData: record(item.instanceData),
  };
}

function parseExtensions(value: unknown): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(record(value)).filter(([key]) => key.includes('.')),
  );
}

function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function array(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function integer(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.trunc(value)
    : fallback;
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

function isPresent<T>(value: T | null): value is T {
  return value !== null;
}
