#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import bisect
import json
import re
import struct
import sys
from collections import defaultdict, OrderedDict
from pathlib import Path
from typing import Dict, List, Tuple, Optional

OBJ_SYM_RE = re.compile(r'^\s*([0-9a-fA-F]+)\s+<([^>]+)>:')

def parse_line_log(path: str) -> Tuple[Dict[int, str], List[int]]:
    """
    Parse 'line_log' with lines like:  0 shell.c:2080
    Return (id->"file:line", ids_in_order).
    """
    id_to_line: Dict[int, str] = {}
    ids_in_order: List[int] = []
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        for raw in f:
            s = raw.strip()
            if not s or s.startswith('#'):
                continue
            parts = s.split(None, 1)
            if len(parts) != 2:
                continue
            try:
                i = int(parts[0])
            except ValueError:
                continue
            if i not in id_to_line:
                ids_in_order.append(i)
            id_to_line[i] = parts[1].strip()
    return id_to_line, ids_in_order

def normalize_symbol(sym: str) -> str:
    # strip version/plt suffixes after '@'
    return sym.split('@', 1)[0]

def parse_objdump_func_map(path: str) -> Tuple[List[int], List[str]]:
    """
    Parse an objdump -d text file into (addrs, symbols) sorted by addr.
    Only function start labels like 'ADDR <name>:' are used.
    """
    entries: List[Tuple[int, str]] = []
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        for raw in f:
            m = OBJ_SYM_RE.match(raw)
            if not m:
                continue
            addr_hex, sym = m.group(1), m.group(2)
            try:
                addr = int(addr_hex, 16)
            except ValueError:
                continue
            entries.append((addr, sym))
    entries.sort(key=lambda x: x[0])
    addrs = [a for a, _ in entries]
    syms  = [s for _, s in entries]
    return addrs, syms

class AddrSymbolMap:
    def __init__(self, addrs: List[int], syms: List[str]) -> None:
        self.addrs = addrs
        self.syms = syms
    def lookup(self, addr: int) -> Optional[str]:
        if not self.addrs:
            return None
        i = bisect.bisect_right(self.addrs, addr) - 1
        if i < 0:
            return None
        return normalize_symbol(self.syms[i])

def parse_slide(value: Optional[str]) -> int:
    if value is None:
        return 0
    v = value.strip().lower()
    return int(v, 16) if v.startswith("0x") else int(v, 10)

def iter_pairs_from_file(path: Path, big_endian: bool = False):
    """
    Stream <uint64 id, uint64 call_addr> pairs from a binary file in chunks.
    """
    fmt = '>QQ' if big_endian else '<QQ'
    size = struct.calcsize(fmt)
    buf = b''
    with path.open('rb') as f:
        while True:
            chunk = f.read(size * 65536)  # read many pairs per chunk
            if not chunk:
                break
            buf += chunk
            usable_len = (len(buf) // size) * size
            data, buf = buf[:usable_len], buf[usable_len:]
            for (id_u64, addr_u64) in struct.iter_unpack(fmt, data):
                yield int(id_u64), int(addr_u64)
    if buf:
        sys.stderr.write(
            f"[warn] {path} has {len(buf)} trailing bytes (not a full pair); ignoring.\n"
        )

def main():
    ap = argparse.ArgumentParser(
        description="Decode icall binary logs (<id,uint64>,<addr,uint64>) into one merged JSON."
    )
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--address-log", help="One binary file with <uint64 id, uint64 call_addr> pairs")
    grp.add_argument("--address-dir", help="Directory containing many address logs (all files are read)")
    ap.add_argument("--line-log", required=True, help="Text file mapping id → 'file:line'")
    ap.add_argument("--func-map", required=True, help="Objdump -d output (text) for symbol addresses")
    ap.add_argument("--output", "-o", default="merged_icalls.json", help="Output JSON path (default: merged_icalls.json)")
    ap.add_argument("--slide", help="Address slide to subtract from call_addr (hex like 0x400000 or decimal)")
    ap.add_argument("--big-endian", action="store_true", help="Interpret binary pairs as big-endian (default little)")
    args = ap.parse_args()

    slide = parse_slide(args.slide)
    id_to_line, ids_in_order = parse_line_log(args.line_log)
    addrs, syms = parse_objdump_func_map(args.func_map)
    symmap = AddrSymbolMap(addrs, syms)

    # Collect input files
    input_paths: List[Path] = []
    if args.address_log:
        p = Path(args.address_log)
        if not p.is_file():
            ap.error(f"--address-log {p} is not a file")
        input_paths = [p]
    else:
        d = Path(args.address_dir)
        if not d.is_dir():
            ap.error(f"--address-dir {d} is not a directory")
        # Every regular file in the directory (deterministic order)
        input_paths = [p for p in sorted(d.iterdir()) if p.is_file()]
        if not input_paths:
            sys.stderr.write(f"[warn] No regular files found in {d}\n")

    # Aggregate: id -> ordered set of targets (use OrderedDict to keep first-seen order)
    per_id_targets: Dict[int, OrderedDict] = defaultdict(OrderedDict)

    total_pairs = 0
    for path in input_paths:
        for id_i, raw_addr in iter_pairs_from_file(path, big_endian=args.big_endian):
            total_pairs += 1
            adj = raw_addr - slide
            sym = symmap.lookup(adj)
            if sym is None:
                sym = f"0x{adj:x}"
            per_id_targets[id_i].setdefault(sym, None)

    # Finalize order: follow line_log order first, then any extra ids found in logs
    final_ids: List[int] = []
    seen = set()
    for i in ids_in_order:
        if i in per_id_targets:
            final_ids.append(i)
            seen.add(i)
    for i in per_id_targets.keys():
        if i not in seen:
            final_ids.append(i)

    result = []
    for i in final_ids:
        targets = list(per_id_targets[i].keys())
        line = id_to_line.get(i, f"UNKNOWN:{i}")
        result.append({"line": line, "id": str(i), "targets": targets})

    with open(args.output, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=4)

    print(f"[ok] Files read: {len(input_paths)}, pairs: {total_pairs}, unique IDs: {len(per_id_targets)}")
    print(f"[ok] Wrote {len(result)} records to {args.output}")

if __name__ == "__main__":
    main()

# # directory of address_log
# python3 address_to_json.py \
#   --address-dir /path/to/logs \
#   --line-log line_log.txt \
#   --func-map func_map.txt \
#   --output merged_icalls.json

# # single file
# python3 address_to_json.py \
#   --address-log /path/to/address_log.bin \
#   --line-log line_log.txt \
#   --func-map func_map.txt \
#   --output merged_icalls.json