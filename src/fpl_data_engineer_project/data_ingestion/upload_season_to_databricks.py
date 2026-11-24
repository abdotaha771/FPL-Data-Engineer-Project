"""Upload the merged 2026-2027 FPL CSV files to a Databricks Volume."""

import argparse
import os
from pathlib import Path, PurePosixPath

from databricks.sdk import WorkspaceClient
from dotenv import load_dotenv

SEASON = "2026-2027"
SOURCE_DIR = Path("data") / SEASON
FILES = ("matches.csv", "playermatchstats.csv", "players.csv", "teams.csv")
load_dotenv(Path(__file__).with_name(".env"))
load_dotenv()
DEFAULT_VOLUME_PATH = os.getenv("DATABRICKS_VOLUME_PATH", f"/Volumes/fpl_db/raw/{SEASON}")


def upload_season(volume_path: str, source_dir: Path = SOURCE_DIR) -> int:
    """Upload all merged season CSVs and return the number of uploaded files."""
    destination = PurePosixPath(volume_path.rstrip("/"))
    if not str(destination).startswith("/Volumes/"):
        raise ValueError("volume_path must be a Unity Catalog path starting with /Volumes/")

    host = os.getenv("DATABRICKS_HOST", "").strip()
    token = os.getenv("DATABRICKS_TOKEN", "").strip()
    if not host:
        raise RuntimeError("DATABRICKS_HOST is not configured")
    if not token:
        raise RuntimeError("DATABRICKS_TOKEN is not configured")
    if not host.startswith(("http://", "https://")):
        host = f"https://{host}"

    client = WorkspaceClient(host=host, token=token)
    uploaded = 0
    for file_name in FILES:
        source_path = source_dir / file_name
        if not source_path.is_file():
            raise FileNotFoundError(f"Required season file does not exist: {source_path}")
        target_path = str(destination / file_name)
        with source_path.open("rb") as contents:
            client.files.upload(target_path, contents, overwrite=True)
        uploaded += 1
        print(f"Uploaded {source_path} -> {target_path}")
    return uploaded


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--volume-path",
        default=DEFAULT_VOLUME_PATH,
        help=f"Destination Unity Catalog Volume directory (default: {DEFAULT_VOLUME_PATH})",
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=SOURCE_DIR,
        help=f"Local directory containing the merged CSVs (default: {SOURCE_DIR})",
    )
    args = parser.parse_args()
    count = upload_season(args.volume_path, args.source_dir)
    print(f"Uploaded {count} season files to {args.volume_path}")


if __name__ == "__main__":
    main()
