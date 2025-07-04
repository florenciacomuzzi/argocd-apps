import argparse
import hashlib
import os
import sys
from typing import Dict, List, Set, Tuple

# Added for YAML parsing
import yaml

# Optional pathspec for .gitignore parsing
try:
    import pathspec  # type: ignore
except ImportError:  # pragma: no cover
    pathspec = None


# ---------------- Color helpers ----------------

class Color:
    RED = "\033[31m"
    YELLOW = "\033[33m"
    GREEN = "\033[32m"
    CYAN = "\033[36m"
    RESET = "\033[0m"

    @staticmethod
    def wrap(text: str, colour: str) -> str:
        return f"{colour}{text}{Color.RESET}"


# ---------------- .gitignore helpers ----------------


def load_gitignore(base_dir: str) -> "pathspec.PathSpec | None":
    """Load .gitignore rules as a pathspec.PathSpec object.

    Returns None if unavailable.
    """
    gitignore_path = os.path.join(base_dir, ".gitignore")

    if not os.path.isfile(gitignore_path):
        return None

    if pathspec is None:
        print(
            Color.wrap(
                "Warning: pathspec not installed – "
                ".gitignore patterns will be ignored",
                Color.YELLOW
            ),
            file=sys.stderr
        )
        return None

    with open(gitignore_path, "r", encoding="utf-8") as fp:
        lines = fp.readlines()

    # Use gitwildmatch to mimic Git behaviour
    return pathspec.PathSpec.from_lines("gitwildmatch", lines)


def file_hash(path: str) -> str:
    """Return md5 hash of file contents for comparison."""
    hash_md5 = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


# ---------------- YAML-specific helpers ----------------


def is_yaml_file(path: str) -> bool:
    """Return True if the filename suggests a YAML file."""
    ext = os.path.splitext(path)[1].lower()
    return ext in {".yml", ".yaml"}


def diff_data(a, b, path: str = "") -> List[str]:
    """Recursively diff two YAML-loaded python objects.

    Returns list of human-readable diffs.
    """
    diffs: List[str] = []

    # Helper to build child path
    def child(p: str, key: str) -> str:
        return f"{p}.{key}" if p else str(key)

    # Dict vs Dict
    if isinstance(a, dict) and isinstance(b, dict):
        keys = set(a.keys()) | set(b.keys())
        for k in sorted(keys):
            if k not in a:
                diffs.append(f"Missing key in A: {child(path, k)}")
            elif k not in b:
                diffs.append(f"Missing key in B: {child(path, k)}")
            else:
                diffs.extend(diff_data(a[k], b[k], child(path, k)))

    # List vs List
    elif isinstance(a, list) and isinstance(b, list):
        max_len = max(len(a), len(b))
        for idx in range(max_len):
            idx_path = child(path, f"[{idx}]")
            if idx >= len(a):
                diffs.append(f"Missing index in A: {idx_path}")
            elif idx >= len(b):
                diffs.append(f"Missing index in B: {idx_path}")
            else:
                diffs.extend(diff_data(a[idx], b[idx], idx_path))

    # Fallback primitive compare
    else:
        if a != b:
            diffs.append(f"Value differs at {path}: {a!r} != {b!r}")

    return diffs


def diff_yaml_files(path_a: str, path_b: str) -> List[str]:
    """Return list of diff strings between two YAML files.

    Empty list means identical.
    """
    try:
        with open(path_a, "r", encoding="utf-8") as fa, \
             open(path_b, "r", encoding="utf-8") as fb:
            data_a = yaml.safe_load(fa) or {}
            data_b = yaml.safe_load(fb) or {}
    except Exception as exc:
        return [f"Error parsing YAML: {exc}"]

    return diff_data(data_a, data_b)


def list_files(
    base_dir: str,
    ignore_spec: "pathspec.PathSpec | None" = None
) -> Set[str]:
    """Recursively gather all file paths relative to base_dir.

    Respects .gitignore if provided.
    """
    paths: Set[str] = set()

    for root, dirs, files in os.walk(base_dir):
        # Modify dirs in-place to skip ignored directories early
        # (.git always skipped)
        dirs[:] = [
            d
            for d in dirs
            if d != ".git" and (
                ignore_spec is None
                or not ignore_spec.match_file(
                    os.path.relpath(os.path.join(root, d), base_dir)
                )
            )
        ]

        for file in files:
            rel_path = os.path.relpath(os.path.join(root, file), base_dir)
            if ignore_spec is not None and ignore_spec.match_file(rel_path):
                continue
            paths.add(rel_path)

    return paths


def compare_directories(
    dir_a: str,
    dir_b: str,
    ignore_spec: "pathspec.PathSpec | None" = None
) -> Tuple[List[str], List[str], List[str], Dict[str, List[str]]]:
    """Compare two directories.

    Returns four collections:
    - only_in_a: files present only in dir_a
    - only_in_b: files present only in dir_b
    - different: files present in both but with different contents
    - yaml_diffs: mapping from rel_path -> list of key-level diffs
      (only for YAML files)
    """
    files_a = list_files(dir_a, ignore_spec)
    files_b = list_files(dir_b, ignore_spec)

    only_in_a = sorted(files_a - files_b)
    only_in_b = sorted(files_b - files_a)

    common_files = files_a & files_b
    different: List[str] = []
    yaml_diffs: Dict[str, List[str]] = {}

    for rel_path in sorted(common_files):
        a_path = os.path.join(dir_a, rel_path)
        b_path = os.path.join(dir_b, rel_path)

        if is_yaml_file(rel_path):
            diffs = diff_yaml_files(a_path, b_path)
            if diffs:
                different.append(rel_path)
                yaml_diffs[rel_path] = diffs
        else:
            if file_hash(a_path) != file_hash(b_path):
                different.append(rel_path)

    return only_in_a, only_in_b, different, yaml_diffs


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare two directories recursively, "
                    "reporting extra files and differing file contents."
    )
    parser.add_argument("dir_a", help="First directory to compare")
    parser.add_argument("dir_b", help="Second directory to compare")
    parser.add_argument(
        "--warn-only", "-w", action="store_true",
        help="Do not fail (exit 0) when differences are found; "
             "just output warnings"
    )
    args = parser.parse_args()

    dir_a = os.path.abspath(args.dir_a)
    dir_b = os.path.abspath(args.dir_b)

    if not os.path.isdir(dir_a):
        print(f"Error: {dir_a} is not a directory", file=sys.stderr)
        sys.exit(2)
    if not os.path.isdir(dir_b):
        print(f"Error: {dir_b} is not a directory", file=sys.stderr)
        sys.exit(2)

    # Load .gitignore once (assume script run from repo root or pass cwd)
    ignore_spec = load_gitignore(os.getcwd())

    only_in_a, only_in_b, different, yaml_diffs = compare_directories(
        dir_a, dir_b, ignore_spec
    )

    # Note: warnings collection removed as unused

    if not (only_in_a or only_in_b or different):
        print(Color.wrap("Directories are identical ✨", Color.GREEN))
        sys.exit(0)

    if only_in_a:
        print(Color.wrap("Files only in " + dir_a, Color.CYAN))
        for path in only_in_a:
            print(Color.wrap("  + " + path, Color.YELLOW))
        print()

    if only_in_b:
        print(Color.wrap("Files only in " + dir_b, Color.CYAN))
        for path in only_in_b:
            print(Color.wrap("  + " + path, Color.YELLOW))
        print()

    if different:
        header = (
            "Files with differing contents:"
            if not args.warn_only
            else "Files with differing contents (warning):"
        )
        colour = Color.RED if not args.warn_only else Color.YELLOW
        print(Color.wrap(header, Color.CYAN))
        for path in different:
            print(Color.wrap("  ~ " + path, colour))
            # If YAML, show key-level diffs
            if path in yaml_diffs:
                for line in yaml_diffs[path]:
                    print(Color.wrap("     " + line, colour))
        print()

    # Determine exit code
    if different and not args.warn_only:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
