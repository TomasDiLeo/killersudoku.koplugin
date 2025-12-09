import struct
import os

# ---------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------
INPUT_DIR = "plain"        # folder containing 16k .txt files
OUTPUT_PUZZLES = "lua/puzzles.bin"
OUTPUT_INDEX = "lua/index.bin"
# ---------------------------------------------------------


def parse_puzzle_file(path):
    """
    Parses a single Killer Sudoku txt file.
    Returns a list of cages, each cage = (sum, [cells]).
    Where each cell is encoded as 0-80 (row*9+col).
    """
    cages = []

    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            parts = line.split()
            cage_sum = int(parts[0])
            cell_strs = parts[1:]

            encoded_cells = []
            for c in cell_strs:
                # Expecting exactly two digits per cell, e.g. "47"
                r = int(c[0])
                col = int(c[1])
                enc = r * 9 + col
                encoded_cells.append(enc)

            cages.append((cage_sum, encoded_cells))

    return cages


def main():
    # Collect all txt files in INPUT_DIR (sorted for reproducibility)
    files = [f for f in os.listdir(INPUT_DIR) if f.lower().endswith(".txt")]
    files.sort()

    offsets = []
    byte_position = 0

    with open(OUTPUT_PUZZLES, "wb") as out_puzzles:
        for fname in files:
            path = os.path.join(INPUT_DIR, fname)

            # Record starting byte offset of this puzzle
            offsets.append(byte_position)

            cages = parse_puzzle_file(path)

            # Write number of cages (1 byte)
            out_puzzles.write(struct.pack("B", len(cages)))
            byte_position += 1

            # Write each cage
            for cage_sum, cells in cages:
                # Sum (1 byte)
                out_puzzles.write(struct.pack("B", cage_sum))
                byte_position += 1

                # Number of cells (1 byte)
                out_puzzles.write(struct.pack("B", len(cells)))
                byte_position += 1

                # Each cell (1 byte)
                for c in cells:
                    out_puzzles.write(struct.pack("B", c))
                    byte_position += 1

    # Write index file (32-bit little-endian integers)
    with open(OUTPUT_INDEX, "wb") as out_index:
        for off in offsets:
            out_index.write(struct.pack("<I", off))  # unsigned int LE


if __name__ == "__main__":
    main()
