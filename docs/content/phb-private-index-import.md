# PHB 2024 Private Index Import

This project must not commit or redistribute commercial rulebook text. For a
user-owned PDF, the local importer can generate a private content index that is
kept outside git and then imported into the user's own server.

## Generate The Draft

```powershell
$pdf = "C:\Users\26047\Downloads\龙与地下城 玩家手册 2024.pdf"
python scripts/generate_phb_private_index.py "$pdf"
```

The default output is:

```text
private-imports/phb-2024-index-draft.content.private.json
```

`private-imports/` is ignored by git. The generated package stores names,
content type, source page, outline path, bilingual name fields, and lightweight
classification metadata. It does not extract rules descriptions.

## Current Coverage

- `class`: top-level player classes.
- `background`: background names from the origin chapter.
- `species`: species names from the origin chapter.
- `feat`: origin, general, fighting style, and epic boon feat indexes.
- `spell`: spell names grouped by spell level.
- `equipment`: chapter/table/section indexes only; row-level equipment parsing
  still needs a later table parser and DM confirmation UI.

## Import In The Client

1. Log in as DM.
2. Open `资料库`.
3. Use the private draft import action.
4. Paste the generated JSON.
5. Preview and dry-run validate.
6. Import to the currently connected self-hosted server.

JSON import remains available as an advanced path, but normal homebrew content
creation should use the GUI form.
