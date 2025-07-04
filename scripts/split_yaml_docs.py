import argparse
import os
import re
import sys
from typing import List

import yaml

SAFE_CHARS = re.compile(r"[^a-zA-Z0-9_.-]")


def sanitize(value: str) -> str:
    """Sanitize string for filenames."""
    return SAFE_CHARS.sub("-", value.lower())


def build_filename(base: str, idx: int, kind: str, name: str) -> str:
    stem, _ = os.path.splitext(base)
    safe_kind = sanitize(kind) if kind else f"doc{idx+1}"
    safe_name = sanitize(name) if name else f"item{idx+1}"
    return f"{stem}_{safe_kind}_{safe_name}.yaml"


def split_file(path: str, delete_original: bool = False, dry_run: bool = False) -> List[str]:
    """Split a YAML file into single-document files. Returns list of new files."""
    new_files: List[str] = []
    with open(path, "r", encoding="utf-8") as fp:
        docs = list(yaml.safe_load_all(fp))

    if len(docs) <= 1:
        return new_files  # nothing to split

    for idx, doc in enumerate(docs):
        kind = doc.get("kind") if isinstance(doc, dict) else "unk"
        name = doc.get("metadata", {}).get("name") if isinstance(doc, dict) else "noname"
        new_name = build_filename(os.path.basename(path), idx, kind or "unk", name or "noname")
        new_path = os.path.join(os.path.dirname(path), new_name)
        if dry_run:
            print("DRY-RUN: would create", new_path)
        else:
            with open(new_path, "w", encoding="utf-8") as out:
                yaml.safe_dump(doc, out, sort_keys=False)
            new_files.append(new_path)
            print("Created", new_path)

    if delete_original and not dry_run:
        os.remove(path)
        print("Removed original", path)

    return new_files


def walk_and_split(root: str, delete_original: bool = False, dry_run: bool = False) -> None:
    for dirpath, _dirs, files in os.walk(root):
        for file in files:
            if file.endswith((".yml", ".yaml")):
                split_file(os.path.join(dirpath, file), delete_original=delete_original, dry_run=dry_run)


def main() -> None:
    parser = argparse.ArgumentParser(description="Split multi-document YAML files into single-document files.")
    parser.add_argument("paths", nargs="+", help="File or directory paths to process")
    parser.add_argument("--delete-original", "-d", action="store_true", help="Delete the original multi-doc file after splitting")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without writing files")
    args = parser.parse_args()

    for p in args.paths:
        abs_p = os.path.abspath(p)
        if not os.path.exists(abs_p):
            print("Path not found:", abs_p, file=sys.stderr)
            continue
        if os.path.isdir(abs_p):
            walk_and_split(abs_p, delete_original=args.delete_original, dry_run=args.dry_run)
        else:
            split_file(abs_p, delete_original=args.delete_original, dry_run=args.dry_run)


if __name__ == "__main__":
    main() 