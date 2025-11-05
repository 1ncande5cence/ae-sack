#!/usr/bin/env python3

import os
import re

def load_line_log(line_log_path):
    """Load line_log file and create id -> location mapping"""
    id_to_location = {}
    try:
        with open(line_log_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    parts = line.split(' ', 1)
                    if len(parts) == 2:
                        id_num = int(parts[0])
                        location = parts[1]
                        id_to_location[id_num] = location
    except FileNotFoundError:
        print(f"Warning: {line_log_path} not found")
    return id_to_location

def load_func_map(func_map_path):
    """Load func_map file and create address -> function mapping"""
    address_to_function = {}
    try:
        with open(func_map_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    # Parse lines like: 000000000057a290 <ngx_http_chunked_filter_init>:
                    # More general pattern that matches any hex address followed by function name
                    match = re.search(r'([0-9a-fA-F]+)\s*<([^>]+)>', line)
                    if match:
                        # Remove leading zeros and add 0x prefix
                        hex_part = match.group(1).lstrip('0')
                        if not hex_part:  # Handle case where address is all zeros
                            hex_part = '0'
                        address = '0x' + hex_part
                        function_name = match.group(2)
                        address_to_function[address] = function_name
    except FileNotFoundError:
        print(f"Warning: {func_map_path} not found")
    return address_to_function

def parse_attack_line(line):
    """Parse attack log line and extract components"""
    line = line.strip()
    if not line:
        return None
    
    # Handle both formats:
    # 134_5743248(0x57a290)_7
    # 134_5743248(0x57a290)
    
    # Extract icall_id, address, and optional enter_time
    match = re.match(r'(\d+)_(\d+)\((0x[0-9a-f]+)\)(?:_(\d+))?', line)
    if match:
        icall_id = int(match.group(1))
        address = match.group(3)
        enter_time = match.group(4) if match.group(4) else None
        return {
            'icall_id': icall_id,
            'address': address,
            'enter_time': enter_time
        }
    return None

def generate_report(unique_attack_log_path, line_log_path, func_map_path, output_file=None):
    """Generate the report by translating attack log entries"""
    
    # Load mappings
    id_to_location = load_line_log(line_log_path)
    address_to_function = load_func_map(func_map_path)
    
    # Open output file if specified
    output_f = None
    if output_file:
        try:
            output_f = open(output_file, 'w')
        except IOError as e:
            print(f"Error: Could not open output file {output_file}: {e}")
            return
    
    def print_output(text):
        """Print to both console and file if output file is specified"""
        print(text)
        if output_f:
            output_f.write(text + '\n')
    
    # Process unique_attack.log
    try:
        with open(unique_attack_log_path, 'r') as f:
            for line in f:
                parsed = parse_attack_line(line)
                if parsed:
                    icall_id = parsed['icall_id']
                    address = parsed['address']
                    enter_time = parsed['enter_time']
                    
                    # Get location from line_log
                    location = id_to_location.get(icall_id, f"unknown location for id {icall_id}")
                    
                    # Get function name from func_map
                    function_name = address_to_function.get(address, f"unknown function for address {address}")
                    
                    # Generate output line
                    output_parts = [
                        f"icall {icall_id}: {location}",
                        f"flip to {function_name}"
                    ]
                    
                    if enter_time:
                        output_parts.append(f"at enter time {enter_time}")
                    
                    print_output(", ".join(output_parts))
                else:
                    print_output(f"Warning: Could not parse line: {line.strip()}")
                    
    except FileNotFoundError:
        print_output(f"Error: {unique_attack_log_path} not found")
    finally:
        if output_f:
            output_f.close()
            #print(f"Report also saved to: {output_file}")

def main():
    import sys
    
    # Check command line arguments
    if len(sys.argv) < 2:
        print("Usage: python3 report.py <attack_log_file> [output_file]")
        print("Example: python3 report.py satisfied_attack.log")
        print("Example: python3 report.py satisfied_attack.log report.txt")
        sys.exit(1)
    
    # Get arguments
    attack_log_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    # File paths - assume log files are in ./log/ relative to the attack log file
    if os.path.isabs(attack_log_file):
        # If absolute path, use the directory containing the attack log
        base_dir = os.path.dirname(attack_log_file)
        attack_log_path = attack_log_file
    else:
        # If relative path, use current directory as base
        base_dir = "./"
        attack_log_path = os.path.join(base_dir, attack_log_file)
    
    line_log = os.path.join(base_dir, "log", "line_log")
    func_map = os.path.join(base_dir, "log", "func_map")
    
    print(f"Attack Report for: {attack_log_file}")
    if output_file:
        print(f"Output file: {output_file}")
    print("=" * 50)
    generate_report(attack_log_path, line_log, func_map, output_file)

if __name__ == "__main__":
    main()

# run the script

# python3 report.py satisfied_attack.log report_satisfied.txt
# python3 report.py unique_attack.log report_unique.txt