"""
Merge two JSON arrays (subgt.json first, static_out.json second).

Behavior:
- Output contains the union of lines.
- Ordering:
    1) All lines that appear in subgt.json, in the SAME ORDER they appear there.
    2) Then any lines that appear ONLY in static_out.json, in their original order.
- For each overlapping line:
    * targets = subgt.targets + (static.targets minus duplicates), preserving order.
    * id rule:
        - collect all non-"N/A" ids from both sides
        - if none -> "N/A"
        - if exactly one unique -> that id
        - if more than one unique -> "N/A"

Usage:
    merge_static_json.py subgt.json static_out.json merged.json
"""

import sys, json
from pathlib import Path

def _normalize_entries(arr):
    """Ensure list of dicts with 'line', 'id', 'targets' (list)."""
    norm = []
    for e in arr:
        if not isinstance(e, dict):
            continue
        line = e.get("line")
        if not line:
            continue
        _id = e.get("id", "N/A")
        if _id is None:
            _id = "N/A"
        else:
            _id = str(_id)
        targets = e.get("targets", [])
        if targets is None:
            targets = []
        elif not isinstance(targets, list):
            targets = [targets]
        norm.append({"line": line, "id": _id, "targets": targets})
    return norm

def _index_by_line(entries):
    """Return dict: line -> list of entries (preserve order)."""
    d = {}
    for e in entries:
        d.setdefault(e["line"], []).append(e)
    return d

def _merge_targets(sub_targets, static_targets):
    out = []
    seen = set()
    for t in sub_targets:
        if t not in seen:
            seen.add(t)
            out.append(t)
    for t in static_targets:
        if t not in seen:
            seen.add(t)
            out.append(t)
    return out

def _resolve_id(ids):
    # keep only non-"N/A", non-empty
    non_na = []
    seen = set()
    for i in ids:
        s = str(i).strip() if i is not None else "N/A"
        if not s or s.upper() == "NA":
            s = "N/A"
        if s != "N/A" and s not in seen:
            non_na.append(s)
            seen.add(s)
    if len(non_na) == 0:
        return "N/A"
    if len(non_na) == 1:
        return non_na[0]
    return "N/A"  # conflicting

def merge_with_subgt_order(subgt_entries, static_entries):
    subgt = _normalize_entries(subgt_entries)
    static = _normalize_entries(static_entries)

    static_by_line = _index_by_line(static)
    subgt_by_line = _index_by_line(subgt)

    merged = []
    seen_lines = set()

    # 1) all lines from subgt, in subgt order
    for e in subgt:
        line = e["line"]
        if line in seen_lines:
            continue  # avoid duplicates if subgt itself repeats
        seen_lines.add(line)

        static_list = static_by_line.get(line, [])
        ids = [e["id"]] + [x["id"] for x in static_list]
        final_id = _resolve_id(ids)

        # Merge targets: subgt first, then any from all matching static entries
        static_targets_flat = []
        for x in static_list:
            static_targets_flat.extend(x["targets"])
        merged_targets = _merge_targets(e["targets"], static_targets_flat)

        merged.append({"line": line, "id": final_id, "targets": merged_targets})

    # 2) append static-only lines in static order
    added_static_only = set()
    for x in static:
        line = x["line"]
        if line in seen_lines or line in added_static_only:
            continue
        # ids from all static entries for this line
        ids = [y["id"] for y in static_by_line.get(line, [])]
        final_id = _resolve_id(ids)
        static_targets_flat = []
        for y in static_by_line.get(line, []):
            static_targets_flat.extend(y["targets"])
        merged_targets = _merge_targets([], static_targets_flat)

        merged.append({"line": line, "id": final_id, "targets": merged_targets})
        added_static_only.add(line)

    return merged

def main():
    if len(sys.argv) != 4:
        print("Usage: merge_static_json.py subgt.json static_out.json merged.json")
        sys.exit(1)

    subgt_path = Path(sys.argv[1])
    static_path = Path(sys.argv[2])
    out_path = Path(sys.argv[3])

    subgt_entries = json.loads(subgt_path.read_text(encoding="utf-8"))
    static_entries = json.loads(static_path.read_text(encoding="utf-8"))

    if not isinstance(subgt_entries, list) or not isinstance(static_entries, list):
        print("Error: both inputs must be JSON arrays")
        sys.exit(2)

    merged = merge_with_subgt_order(subgt_entries, static_entries)
    out_path.write_text(json.dumps(merged, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {out_path} with {len(merged)} entries.")

if __name__ == "__main__":
    main()


# python3 merge_json.py subgt.json tfa_out.json merged_tfa_subgt.json
# python3 merge_json.py subgt.json mlta_out.json merged_mlta_subgt.json
