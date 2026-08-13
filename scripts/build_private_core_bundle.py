import argparse
import json
from pathlib import Path
from typing import Any, Iterable


CORE_PACKAGE_ID = "core-2024-private-test"


def _rewrite_references(value: Any, package_ids: Iterable[str]) -> Any:
    if isinstance(value, dict):
        return {
            key: _rewrite_references(item, package_ids)
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [_rewrite_references(item, package_ids) for item in value]
    if isinstance(value, str):
        rewritten = value
        for package_id in package_ids:
            rewritten = rewritten.replace(
                f"{package_id}:", f"{CORE_PACKAGE_ID}:"
            )
        return rewritten
    return value


def merge_private_bundles(
    bundle_paths: Iterable[Path], output_path: Path
) -> dict[str, Any]:
    packages = [
        json.loads(Path(path).read_text(encoding="utf-8"))
        for path in bundle_paths
    ]
    package_ids = [package["id"] for package in packages]
    entries: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for package in packages:
        for source_entry in package["entries"]:
            entry = _rewrite_references(source_entry, package_ids)
            entry_id = entry["id"]
            if not entry_id.startswith(f"{CORE_PACKAGE_ID}:"):
                raise ValueError(f"entry id was not rebased: {entry_id}")
            if entry_id in seen_ids:
                raise ValueError(f"duplicate entry id: {entry_id}")
            seen_ids.add(entry_id)
            entries.append(entry)

    bundle = {
        "formatVersion": 2,
        "id": CORE_PACKAGE_ID,
        "name": "2024 核心测试包",
        "version": "0.1.1",
        "locale": "zh-CN",
        "system": "dnd5e-2024",
        "entryCount": len(entries),
        "entries": entries,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(bundle, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    return bundle


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("bundles", nargs="+", type=Path)
    args = parser.parse_args()
    bundle = merge_private_bundles(args.bundles, args.output)
    print(
        f"Private core bundle: {args.output} "
        f"({bundle['entryCount']} entries)"
    )


if __name__ == "__main__":
    main()
