#!/usr/bin/env python3
import sys
import argparse

def main():
    ap = argparse.ArgumentParser(
        description="Group by first ID and detect presence of '[Malformed Packet]'."
    )
    ap.add_argument("file", help="Input file path (use - for stdin)")
    ap.add_argument("--with-out", metavar="FILE", help="Write IDs WITH malformed to this file")
    ap.add_argument("--without-out", metavar="FILE", help="Write IDs WITHOUT malformed to this file")
    args = ap.parse_args()

    # Read lines
    if args.file == "-":
        lines = sys.stdin.read().splitlines()
    else:
        with open(args.file, "r", errors="ignore") as f:
            lines = f.read().splitlines()

    seen = set()
    bad = set()  # IDs that have at least one "[Malformed Packet]"

    for line in lines:
        if not line.strip():
            continue
        # First token is the ID (split on whitespace)
        parts = line.split()
        if not parts:
            continue
        id_ = parts[0]
        seen.add(id_)
        if "[Malformed Packet]" in line:
            bad.add(id_)

    with_malformed = sorted(bad)
    without_malformed = sorted(seen - bad)

    # Print to stdout
    print("WITH_MALFORMED:")
    for x in with_malformed:
        print(x)
    print("\nWITHOUT_MALFORMED:")
    for x in without_malformed:
        print(x)

    # Optional file outputs
    if args.with_out:
        with open(args.with_out, "w") as f:
            f.write("\n".join(with_malformed) + ("\n" if with_malformed else ""))
    if args.without_out:
        with open(args.without_out, "w") as f:
            f.write("\n".join(without_malformed) + ("\n" if without_malformed else ""))

if __name__ == "__main__":
    main()


#
# python3 group_malformed.py probe_nginx_log \
#   --with-out ids_with_malformed.txt \
#   --without-out ids_without_malformed.txt