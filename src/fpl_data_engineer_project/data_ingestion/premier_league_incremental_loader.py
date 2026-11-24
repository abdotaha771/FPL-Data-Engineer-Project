"""Incrementally download and merge Premier League gameweek CSV files."""

import argparse
import csv
from http.client import IncompleteRead
import json
import time
import tempfile
from pathlib import Path
from typing import Iterable
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

SEASON = "2026-2027"
TOURNAMENT_PATH = "data/2026-2027/By Tournament/Premier League"
FILES = ("matches.csv", "playermatchstats.csv", "players.csv", "teams.csv")
OUTPUT_DIR = Path("data") / SEASON
CACHE_DIR = Path("data") / ".cache" / SEASON / "premier-league"
MANIFEST_PATH = CACHE_DIR / "manifest.json"


class SourceError(RuntimeError):
    """Raised when the upstream source cannot be read or is invalid."""


def _request_json(url: str) -> object:
    request = Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "fpl-data-engineer-project"})
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            with urlopen(request, timeout=60) as response:
                return json.loads(response.read())
        except (HTTPError, URLError, TimeoutError, IncompleteRead, ConnectionResetError) as exc:
            last_error = exc
            if attempt < 2:
                time.sleep(2 * (attempt + 1))
    raise SourceError(f"Unable to read upstream source after retries: {url}") from last_error


def _request_bytes(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": "fpl-data-engineer-project"})
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            with urlopen(request, timeout=60) as response:
                return response.read()
        except (HTTPError, URLError, TimeoutError, IncompleteRead, ConnectionResetError) as exc:
            last_error = exc
            if attempt < 2:
                time.sleep(2 * (attempt + 1))
    raise SourceError(f"Unable to download upstream file after retries: {url}") from last_error


def _gameweek_number(name: str) -> int:
    return int(name.removeprefix("GW"))


def _load_manifest() -> dict[str, str]:
    if not MANIFEST_PATH.exists():
        return {}
    try:
        value = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SourceError(f"Invalid cache manifest: {MANIFEST_PATH}") from exc
    if not isinstance(value, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in value.items()):
        raise SourceError(f"Invalid cache manifest: {MANIFEST_PATH}")
    return value


def _write_atomic(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("wb", dir=path.parent, delete=False) as temporary:
        temporary.write(content)
        temporary_path = Path(temporary.name)
    temporary_path.replace(path)


def _weekly_files() -> list[tuple[str, dict[str, dict[str, str]]]]:
    source = "https://api.github.com/repos/olbauday/FPL-Core-Insights/git/trees/main?recursive=1"
    tree = _request_json(source)
    if not isinstance(tree, dict) or not isinstance(tree.get("tree"), list):
        raise SourceError(f"Expected a repository tree: {source}")

    prefix = f"{TOURNAMENT_PATH}/"
    gameweeks: dict[str, dict[str, dict[str, str]]] = {}
    for item in tree["tree"]:
        if not isinstance(item, dict) or item.get("type") != "blob":
            continue
        path = str(item.get("path", ""))
        if not path.startswith(prefix):
            continue
        relative = path.removeprefix(prefix)
        parts = relative.split("/")
        if len(parts) != 2 or parts[0] == "" or parts[1] not in FILES:
            continue
        gameweek, file_name = parts
        if not gameweek.startswith("GW"):
            continue
        download_url = f"https://raw.githubusercontent.com/olbauday/FPL-Core-Insights/main/{quote(path, safe='/')}"
        gameweeks.setdefault(gameweek, {})[file_name] = {
            "sha": str(item.get("sha", "")),
            "download_url": download_url,
        }

    return sorted(gameweeks.items(), key=lambda item: _gameweek_number(item[0]))


def sync_source(full_refresh: bool = False) -> tuple[int, int]:
    """Cache selected files for all available gameweeks.

    Returns ``(downloaded_file_count, available_gameweek_count)``.
    """
    manifest = {} if full_refresh else _load_manifest()
    downloaded = 0
    gameweeks = _weekly_files()
    if not gameweeks:
        raise SourceError("No gameweek directories were found upstream.")

    for name, files in gameweeks:
        missing = [file_name for file_name in FILES if file_name not in files]
        if missing:
            raise SourceError(f"{name} is missing required files: {', '.join(missing)}")

        for file_name in FILES:
            item = files[file_name]
            cache_key = f"{name}/{file_name}"
            sha = item["sha"]
            destination = CACHE_DIR / name / file_name
            if not sha:
                raise SourceError(f"Missing SHA for upstream file: {cache_key}")
            if manifest.get(cache_key) != sha or not destination.exists():
                download_url = item["download_url"]
                if not download_url:
                    raise SourceError(f"Missing download URL for upstream file: {cache_key}")
                _write_atomic(destination, _request_bytes(download_url))
                manifest[cache_key] = sha
                downloaded += 1

    _write_atomic(MANIFEST_PATH, json.dumps(manifest, indent=2, sort_keys=True).encode("utf-8"))
    return downloaded, len(gameweeks)


def _read_rows(paths: Iterable[Path]) -> tuple[list[str], list[dict[str, str]]]:
    fieldnames: list[str] = []
    rows: list[dict[str, str]] = []
    for path in paths:
        try:
            with path.open(newline="", encoding="utf-8-sig") as source:
                reader = csv.DictReader(source)
                if reader.fieldnames is None:
                    raise SourceError(f"CSV has no header: {path}")
                for field in reader.fieldnames:
                    if field not in fieldnames:
                        fieldnames.append(field)
                rows.extend(dict(row) for row in reader)
        except OSError as exc:
            raise SourceError(f"Unable to read cached file: {path}") from exc
    return fieldnames, rows


def _row_key(file_name: str, row: dict[str, str]) -> tuple[str, ...] | None:
    if file_name == "matches.csv":
        return (row.get("match_id", ""),)
    if file_name == "playermatchstats.csv":
        return (row.get("player_id", ""), row.get("match_id", ""))
    if file_name == "players.csv":
        return (row.get("player_id", ""),)
    if file_name == "teams.csv":
        return (row.get("id",),)
    return None


def merge_cached_files(gameweek_count: int) -> None:
    """Merge cached gameweeks into the season-level CSV outputs."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    gameweeks = sorted(
        (path for path in CACHE_DIR.glob("GW*") if path.is_dir()),
        key=lambda path: _gameweek_number(path.name),
    )
    if len(gameweeks) != gameweek_count:
        raise SourceError("Cache does not contain every gameweek returned by the source.")

    for file_name in FILES:
        paths = [gameweek / file_name for gameweek in gameweeks]
        fields, rows = _read_rows(paths)
        keyed: dict[tuple[str, ...], dict[str, str]] = {}
        unkeyed: list[dict[str, str]] = []
        for row in rows:
            key = _row_key(file_name, row)
            if key is None or any(value == "" for value in key):
                unkeyed.append(row)
            else:
                keyed[key] = row
        merged = list(keyed.values()) + unkeyed
        output = OUTPUT_DIR / file_name
        with tempfile.NamedTemporaryFile("w", newline="", encoding="utf-8", dir=OUTPUT_DIR, delete=False) as temporary:
            writer = csv.DictWriter(temporary, fieldnames=fields, extrasaction="ignore")
            writer.writeheader()
            writer.writerows({field: row.get(field, "") for field in fields} for row in merged)
            temporary_path = Path(temporary.name)
        temporary_path.replace(output)


def run(full_refresh: bool = False) -> tuple[int, int]:
    downloaded, gameweeks = sync_source(full_refresh=full_refresh)
    merge_cached_files(gameweeks)
    return downloaded, gameweeks


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full-refresh", action="store_true", help="Ignore cached SHAs and download every weekly file.")
    args = parser.parse_args()
    try:
        downloaded, gameweeks = run(full_refresh=args.full_refresh)
    except SourceError as exc:
        parser.error(str(exc))
    print(f"Merged {gameweeks} gameweeks into {len(FILES)} files; downloaded {downloaded} changed files.")


if __name__ == "__main__":
    main()
