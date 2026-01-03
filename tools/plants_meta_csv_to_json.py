#!/usr/bin/env python3
"""
Convert a curated plant metadata CSV/TSV into assets/data/plants_meta.json.

This file is meant to fill UI fields that GBIF occurrences do not provide:
  - commonName, wikipedia
  - image (Wikimedia/other URL)
  - idMarkers, lookalikeWarning
  - recipe (prep/simple/pairing)

Expected input headers (minimal):
  taxonKey, scientificName, commonName

Optional headers:
  id, wikipedia
  imageUrl, imageFilePage, imageCreditUrl
  idMarkers, lookalikeWarning
  recipePrep, recipeSimple, recipePairing

Example row:
  taxonKey,scientificName,commonName,wikipedia,imageUrl,idMarkers,lookalikeWarning,recipePrep,recipeSimple,recipePairing
  7960979,Urtica dioica,Stinging nettle,https://en.wikipedia.org/wiki/Urtica_dioica,https://upload.wikimedia.org/...,"Opposite serrated leaves...","Don't confuse with...","Blanch leaves...","Soup...","Garlic, lemon..."
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Any, Dict, Optional


def _sniff_delimiter(path: Path) -> str:
    sample = path.read_text(encoding="utf-8", errors="ignore")[:4096]
    if "\t" in sample and (sample.count("\t") > sample.count(",")):
        return "\t"
    return ","


def _safe_int(v: str) -> Optional[int]:
    v = (v or "").strip()
    if not v:
        return None
    try:
        return int(float(v))
    except Exception:
        return None


def _slugify_id(sci_name: str) -> str:
    # Prefer genus_species as stable-ish id.
    parts = sci_name.strip().split()
    base = "_".join(parts[:2]) if len(parts) >= 2 else sci_name.strip()
    base = base.lower()
    base = re.sub(r"[^a-z0-9_]+", "_", base)
    base = re.sub(r"_+", "_", base).strip("_")
    return base or "plant"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True, help="Path to meta CSV/TSV")
    ap.add_argument("--out", dest="out", required=True, help="Output JSON path")
    ap.add_argument("--version", default="generated")
    ap.add_argument("--delimiter", default="", help="Force delimiter: ',' or '\\t'")
    args = ap.parse_args()

    inp = Path(args.inp)
    out = Path(args.out)
    delim = args.delimiter or _sniff_delimiter(inp)
    if args.delimiter == "\\t":
        delim = "\t"

    plants: list[dict[str, Any]] = []
    with inp.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter=delim)
        for r in reader:
            tk = _safe_int(r.get("taxonKey") or "")
            sci = (r.get("scientificName") or "").strip()
            common = (r.get("commonName") or "").strip()
            if tk is None or not sci:
                continue

            pid = (r.get("id") or "").strip() or _slugify_id(sci)
            wikipedia = (r.get("wikipedia") or "").strip()

            image_url = (r.get("imageUrl") or "").strip()
            image_file_page = (r.get("imageFilePage") or "").strip()
            image_credit_url = (r.get("imageCreditUrl") or "").strip()

            plant: Dict[str, Any] = {
                "id": pid,
                "taxonKey": tk,
                "scientificName": sci,
                "commonName": common,
            }

            if wikipedia:
                plant["wikipedia"] = wikipedia

            if image_url or image_file_page or image_credit_url:
                img: Dict[str, Any] = {}
                if image_url:
                    img["url"] = image_url
                if image_file_page:
                    img["filePage"] = image_file_page
                if image_credit_url:
                    img["creditUrl"] = image_credit_url
                plant["image"] = img

            id_markers = (r.get("idMarkers") or "").strip()
            if id_markers:
                plant["idMarkers"] = id_markers

            lookalike = (r.get("lookalikeWarning") or "").strip()
            if lookalike:
                plant["lookalikeWarning"] = lookalike

            recipe_prep = (r.get("recipePrep") or "").strip()
            recipe_simple = (r.get("recipeSimple") or "").strip()
            recipe_pairing = (r.get("recipePairing") or "").strip()
            if recipe_prep or recipe_simple or recipe_pairing:
                plant["recipe"] = {
                    "prep": recipe_prep,
                    "simple": recipe_simple,
                    "pairing": recipe_pairing,
                }

            plants.append(plant)

    plants.sort(key=lambda p: (p.get("commonName") or p.get("scientificName") or ""))

    data: Dict[str, Any] = {
        "version": args.version,
        "plants": plants,
    }

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {out} ({len(plants)} plants)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

