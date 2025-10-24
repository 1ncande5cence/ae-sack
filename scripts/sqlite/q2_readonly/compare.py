#!/usr/bin/env python3
import argparse
import sys

def load_entries(path, use_two_ids=True):
    """
    Load log file into a dict:
    - if use_two_ids=True → key = "id1_id2"
    - if use_two_ids=False → key = "id1"
    Value = list of remaining parts
    """
    data = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("_")
            if use_two_ids:
                key = "_".join(parts[:2])  # id1_id2
                rest = "_".join(parts[2:])
            else:
                key = parts[0]            # id1 only
                rest = "_".join(parts[1:])
            data.setdefault(key, []).append(rest)
    return data

def classify(A_file, B_file, use_two_ids=True, only_id=False):
    A = load_entries(A_file, use_two_ids)
    B = load_entries(B_file, use_two_ids)

    # merged keys (deduplicated)
    C = sorted(set(A.keys()) | set(B.keys()))

    categories = {1: set(), 2: set(), 3: set(), 4: set(), "other": set()}

    for key in C:
        a_values = A.get(key, [])
        b_values = B.get(key, [])

        if a_values and b_values:
            if any(a == b for a in a_values for b in b_values):
                categories[1].add(key if only_id else f"{key}_{a_values[0]}")
            elif a_values and b_values:
                categories[2].add(key if only_id else f"{key}")
            else:
                categories["other"].add(key)
        elif not a_values and b_values:
            categories[3].add(key if only_id else f"{key}_{b_values[0]}")
        elif a_values and not b_values:
            categories[4].add(key if only_id else f"{key}_{a_values[0]}")
        else:
            categories["other"].add(key)

    return categories

class CustomArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        sys.stderr.write(f"Error: {message}\n\n")
        self.print_help()
        sys.exit(2)

def format_results(results, label, category_names):
    lines = []
    lines.append(f"\n===== Classification based on {label} =====")
    for cat in [1, 2, 3, 4]:
        lines.append(f"\nCategory {cat} ({category_names[cat]}):")
        for entry in sorted(results[cat]):
            lines.append(f"    {entry}")

    if results["other"]:
        lines.append(f"\nOther ({category_names['other']}):")
        for entry in sorted(results["other"]):
            lines.append(f"    {entry}")

    lines.append("\n=== Summary ===")
    for cat in [1, 2, 3, 4]:
        lines.append(f"Category {cat} ({category_names[cat]}): {len(results[cat])}")
    lines.append(f"Other: {len(results['other'])}")

    return "\n".join(lines)

if __name__ == "__main__":
    parser = CustomArgumentParser(
        description=(
            "Compare two log files (A = branch flipping, B = mem modification) "
            "and classify entries.\n\n"
            "Example:\n"
            "  python3 compare.py ./result.20250912111203.branchonly/full_success_attack.log "
            "./result.20250911143307/full_success_attack.log -o compare.txt\n\n"
            "(⚠️ Always put branch-only file first.)"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("A_file", help="Path to log file A (branch flipping)")
    parser.add_argument("B_file", help="Path to log file B (mem modification)")
    parser.add_argument(
        "-o", "--out", default="compare_output.txt",
        help="Output file to save results (default: compare_output.txt)"
    )
    args = parser.parse_args()

    category_names = {
        1: "Remaining branch flipping",
        2: "Both two methods work",
        3: "Only mem modification work",
        4: "Only branch flipping work",
        "other": "Unclassified cases"
    }

    # First classification (id1_id2, detailed)
    results_two = classify(args.A_file, args.B_file, use_two_ids=True, only_id=False)
    output_two = format_results(results_two, "id1_id2", category_names)

    # Second classification (id1 only, deduplicated IDs only)
    results_one = classify(args.A_file, args.B_file, use_two_ids=False, only_id=True)
    output_one = format_results(results_one, "id1 only (deduplicated)", category_names)

    # Combine
    final_output = output_two + "\n\n" + output_one

    # Print to terminal
    print(final_output)

    # Save to file
    with open(args.out, "w") as f:
        f.write(final_output)

    print(f"\n✅ Results saved to {args.out}")