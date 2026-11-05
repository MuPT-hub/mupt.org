#!/usr/bin/env python3
"""Check and optimize the team portraits used by the Hugo site."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError


DEFAULT_DIRECTORY = Path("static/images/team")
SUPPORTED_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}

# The cards advertise a 400 px intrinsic width. A shorter edge below this size
# must be enlarged even at 1x; 800 px supplies a 2x source without shipping an
# unnecessarily large portrait.
MIN_EDGE = 400
MAX_EDGE = 800
JPEG_QUALITY = 85


def annotation(level: str, path: Path, message: str) -> str:
    """Format a message for people locally and as an annotation in Actions."""
    if os.environ.get("GITHUB_ACTIONS") == "true":
        return f"::{level} file={path}::{message}"
    return f"{level.upper()}: {path}: {message}"


def image_paths(directory: Path) -> list[Path]:
    return sorted(
        path
        for path in directory.iterdir()
        if path.is_file() and path.suffix.lower() in SUPPORTED_SUFFIXES
    )


def inspect(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        return ImageOps.exif_transpose(image).size


def check(directory: Path) -> int:
    if not directory.is_dir():
        print(annotation("error", directory, "team image directory does not exist"))
        return 1

    paths = image_paths(directory)
    if not paths:
        print(annotation("error", directory, "no supported team images found"))
        return 1

    errors = 0
    warnings = 0
    for path in paths:
        try:
            width, height = inspect(path)
        except (OSError, UnidentifiedImageError) as exc:
            print(annotation("error", path, f"cannot decode image: {exc}"))
            errors += 1
            continue

        size_kib = path.stat().st_size / 1024
        print(f"{path}: {width}x{height}, {size_kib:.1f} KiB")

        if min(width, height) < MIN_EDGE:
            print(
                annotation(
                    "warning",
                    path,
                    f"short edge is {min(width, height)} px; below the {MIN_EDGE} px "
                    "display source and may look blurry",
                )
            )
            warnings += 1

        if max(width, height) > MAX_EDGE:
            print(
                annotation(
                    "error",
                    path,
                    f"long edge is {max(width, height)} px; run "
                    "`pixi run optimize-team-images` to reduce it to "
                    f"{MAX_EDGE} px",
                )
            )
            errors += 1

    print(
        f"Checked {len(paths)} team images: {warnings} quality warning(s), "
        f"{errors} error(s)."
    )
    return int(errors > 0)


def save_optimized(image: Image.Image, path: Path) -> None:
    suffix = path.suffix.lower()
    save_args: dict[str, object] = {"optimize": True}

    if suffix in {".jpg", ".jpeg"}:
        if image.mode not in {"RGB", "L"}:
            image = image.convert("RGB")
        save_args.update(quality=JPEG_QUALITY, progressive=True)
    elif suffix == ".webp":
        save_args["quality"] = JPEG_QUALITY

    temporary = path.with_name(f".{path.name}.tmp{path.suffix}")
    try:
        image.save(temporary, **save_args)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def optimize(directory: Path) -> int:
    if not directory.is_dir():
        print(annotation("error", directory, "team image directory does not exist"))
        return 1

    changed = 0
    errors = 0
    for path in image_paths(directory):
        try:
            with Image.open(path) as source:
                image = ImageOps.exif_transpose(source)
                old_size = image.size
                if max(old_size) <= MAX_EDGE:
                    continue
                image.thumbnail((MAX_EDGE, MAX_EDGE), Image.Resampling.LANCZOS)
                save_optimized(image, path)
                print(
                    f"Optimized {path}: {old_size[0]}x{old_size[1]} -> "
                    f"{image.width}x{image.height}"
                )
                changed += 1
        except (OSError, UnidentifiedImageError) as exc:
            print(annotation("error", path, f"cannot optimize image: {exc}"))
            errors += 1

    print(f"Optimized {changed} team image(s); {errors} error(s).")
    return int(errors > 0)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("check", "optimize"))
    parser.add_argument(
        "--directory",
        type=Path,
        default=DEFAULT_DIRECTORY,
        help=f"image directory (default: {DEFAULT_DIRECTORY})",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return check(args.directory) if args.mode == "check" else optimize(args.directory)


if __name__ == "__main__":
    sys.exit(main())
