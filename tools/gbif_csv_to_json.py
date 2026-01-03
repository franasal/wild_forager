#!/usr/bin/env python3
"""
Convert a GBIF occurrence export (TSV/CSV with headers) into an offline JSON dataset
for Wild Forager.

Filters:
  - basisOfRecord == HUMAN_OBSERVATION (default)
  - occurrenceStatus == PRESENT (default)
  - within radiusKm of (centerLat, centerLon)

Privacy:
  - drops recordedBy, identifiedBy, verbatimLocality (and everything not needed)

Outputs:
  - plants_gbif.json: per-taxon occurrences + derived frequency/lastObserved + region info
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from collections import defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


def _parse_date(s: str) -> Optional[str]:
    s = (s or "").strip()
    if not s:
        return None
    # GBIF exports are typically YYYY-MM-DD or ISO timestamps.
    # We normalize to YYYY-MM-DD if possible.
    if "T" in s:
        s = s.split("T", 1)[0]
    try:
        y, m, d = s.split("-", 2)
        date(int(y), int(m), int(d))
        return f"{int(y):04d}-{int(m):02d}-{int(d):02d}"
    except Exception:
        return None


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return r * c


def _safe_float(v: str) -> Optional[float]:
    v = (v or "").strip()
    if not v:
        return None
    try:
        return float(v)
    except Exception:
        return None


def _safe_int(v: str) -> Optional[int]:
    v = (v or "").strip()
    if not v:
        return None
    try:
        return int(float(v))
    except Exception:
        return None


def _sniff_delimiter(path: Path) -> str:
    sample = path.read_text(encoding="utf-8", errors="ignore")[:4096]
    if "\t" in sample and (sample.count("\t") > sample.count(",")):
        return "\t"
    return ","


@dataclass(frozen=True)
class _OccRow:
    taxon_key: int
    species: str
    scientific_name: str
    lat: float
    lon: float
    gbif_id: Optional[int]
    event_date: Optional[str]
    license: Optional[str]


def _iter_rows(
    path: Path,
    delimiter: str,
    basis_of_record: str,
    occurrence_status: str,
    center_lat: float,
    center_lon: float,
    radius_km: float,
) -> Iterable[_OccRow]:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter=delimiter)
        for raw in reader:
            bor = (raw.get("basisOfRecord") or "").strip()
            if basis_of_record and bor != basis_of_record:
                continue
            status = (raw.get("occurrenceStatus") or "").strip()
            if occurrence_status and status != occurrence_status:
                continue

            taxon_key = _safe_int(raw.get("taxonKey") or "")
            lat = _safe_float(raw.get("decimalLatitude") or "")
            lon = _safe_float(raw.get("decimalLongitude") or "")
            if taxon_key is None or lat is None or lon is None:
                continue

            if radius_km > 0:
                if _haversine_km(center_lat, center_lon, lat, lon) > radius_km:
                    continue

            species = (raw.get("species") or "").strip()
            scientific_name = (raw.get("scientificName") or "").strip()
            if not species and scientific_name:
                species = scientific_name

            yield _OccRow(
                taxon_key=taxon_key,
                species=species,
                scientific_name=scientific_name or species,
                lat=lat,
                lon=lon,
                gbif_id=_safe_int(raw.get("gbifID") or ""),
                event_date=_parse_date(raw.get("eventDate") or ""),
                license=(raw.get("license") or "").strip() or None,
            )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True, help="Path to GBIF CSV/TSV export")
    ap.add_argument("--out", dest="out", required=True, help="Output JSON path")
    ap.add_argument("--center-lat", type=float, required=True)
    ap.add_argument("--center-lon", type=float, required=True)
    ap.add_argument("--radius-km", type=float, required=True)
    ap.add_argument("--region-name", default="GBIF radius export")
    ap.add_argument("--basis-of-record", default="HUMAN_OBSERVATION")
    ap.add_argument("--occurrence-status", default="PRESENT")
    ap.add_argument("--delimiter", default="", help="Force delimiter: ',' or '\\t'")
    args = ap.parse_args()

    inp = Path(args.inp)
    out = Path(args.out)
    delim = args.delimiter or _sniff_delimiter(inp)
    if args.delimiter == "\\t":
        delim = "\t"

    by_taxon: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
    names: Dict[int, Tuple[str, str]] = {}
    last_obs: Dict[int, str] = {}

    for r in _iter_rows(
        inp,
        delimiter=delim,
        basis_of_record=args.basis_of_record,
        occurrence_status=args.occurrence_status,
        center_lat=args.center_lat,
        center_lon=args.center_lon,
        radius_km=args.radius_km,
    ):
        names.setdefault(r.taxon_key, (r.species, r.scientific_name))
        occ: Dict[str, Any] = {
            "lat": r.lat,
            "lon": r.lon,
        }
        if r.gbif_id is not None:
            occ["gbifId"] = r.gbif_id
        if r.event_date is not None:
            occ["date"] = r.event_date
            prev = last_obs.get(r.taxon_key)
            if prev is None or r.event_date > prev:
                last_obs[r.taxon_key] = r.event_date
        if r.license is not None:
            occ["license"] = r.license
        by_taxon[r.taxon_key].append(occ)

    plants: List[Dict[str, Any]] = []
    for taxon_key, occs in by_taxon.items():
        species, sci = names.get(taxon_key, ("", ""))
        # stable ordering: most recent first if we have dates
        occs.sort(key=lambda o: o.get("date", ""), reverse=True)
        plants.append(
            {
                "taxonKey": taxon_key,
                "species": species,
                "scientificName": sci,
                "frequency": len(occs),
                "lastObserved": last_obs.get(taxon_key),
                "occurrences": occs,
            }
        )

    plants.sort(key=lambda p: p.get("frequency", 0), reverse=True)

    data: Dict[str, Any] = {
        "version": "generated",
        "filters": {
            "basisOfRecord": args.basis_of_record,
            "occurrenceStatus": args.occurrence_status,
        },
        "region": {
            "name": args.region_name,
            "center": {"lat": args.center_lat, "lon": args.center_lon},
            "radiusKm": args.radius_km,
        },
        "plants": plants,
    }

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {out} ({len(plants)} taxa, {sum(len(p['occurrences']) for p in plants)} occurrences)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

