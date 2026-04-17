#!/bin/bash

# Usage: ./extract.sh <PRINTER_TYPE> <OUTPUT_DIR> <SOURCE_DIR>
# SOURCE_DIR defaults to current directory

PRINTER_ARG="${1}"
OUT_DIR="$(realpath "${2:-./output_profiles}")"
SRC_DIR="$(realpath "${3:-.}")"

if [[ -z "$PRINTER_ARG" ]]; then
    echo "Usage: $0 <PRINTER_TYPE> <OUTPUT_DIR> [SOURCE_DIR]"
    echo "Valid printer types: A1, A1M, P1P, P1S, X1, X1C, X1E, X1-ALL, P2S, H2C, H2D, H2S"
    exit 1
fi

# Build grep pattern(s) for the printer argument
# These are case-insensitive patterns matched against filenames and directory components
build_printer_patterns() {
    local p="${1^^}"  # uppercase for comparison
    case "$p" in
        A1)
            # A1 but NOT A1M or A1_mini - we use a negative lookahead via grep -v in caller
            PATTERNS=("A1")
            EXCLUDE_PATTERNS=("A1M" "A1_mini" "A1 mini")
            ;;
        A1M)
            PATTERNS=("A1M" "A1_mini" "A1 mini" "A1_M")
            EXCLUDE_PATTERNS=()
            ;;
        P1P)
            PATTERNS=("P1P")
            EXCLUDE_PATTERNS=()
            ;;
        P1S)
            PATTERNS=("P1S")
            EXCLUDE_PATTERNS=()
            ;;
        X1)
            PATTERNS=("X1")
            EXCLUDE_PATTERNS=("X1C" "X1E" "X1_Carbon" "X1 Carbon" "X1E")
            ;;
        X1C)
            PATTERNS=("X1C" "X1_Carbon" "X1 Carbon" "X1_carbon")
            EXCLUDE_PATTERNS=()
            ;;
        X1E)
            PATTERNS=("X1E")
            EXCLUDE_PATTERNS=()
            ;;
        X1-ALL)
            PATTERNS=("X1")
            EXCLUDE_PATTERNS=()
            ;;
        P2S)
            PATTERNS=("P2S")
            EXCLUDE_PATTERNS=()
            ;;
        H2C)
            PATTERNS=("H2C")
            EXCLUDE_PATTERNS=()
            ;;
        H2D)
            PATTERNS=("H2D")
            EXCLUDE_PATTERNS=()
            ;;
        H2S)
            PATTERNS=("H2S")
            EXCLUDE_PATTERNS=()
            ;;
        *)
            echo "Unknown printer type: $1"
            echo "Valid: A1, A1M, P1P, P1S, X1, X1C, X1E, X1-ALL, P2S, H2C, H2D, H2S"
            exit 1
            ;;
    esac
}

# Check if a string matches any pattern in PATTERNS (case insensitive)
matches_printer() {
    local str="$1"
    local str_lower="${str,,}"
    for pat in "${PATTERNS[@]}"; do
        local pat_lower="${pat,,}"
        if [[ "$str_lower" == *"$pat_lower"* ]]; then
            # Check exclusions
            local excluded=false
            for excl in "${EXCLUDE_PATTERNS[@]}"; do
                local excl_lower="${excl,,}"
                if [[ "$str_lower" == *"$excl_lower"* ]]; then
                    excluded=true
                    break
                fi
            done
            if [[ "$excluded" == false ]]; then
                return 0
            fi
        fi
    done
    return 1
}

# Extract nozzle size from a string (filename or path component)
# Returns the nozzle size or "unspecified"
extract_nozzle() {
    local str="$1"
    if [[ "$str" =~ 0\.[0-9] ]]; then
        # grab the first match
        echo "$str" | grep -oP '0\.[0-9]' | head -1
    else
        echo "unspecified"
    fi
}

# Sanitize a string for use in a filename
sanitize() {
    local s="$1"
    s="${s// /_}"
    s="${s//\//_}"
    s="${s//+/_}"
    echo "$s"
}

build_printer_patterns "$PRINTER_ARG"
mkdir -p "$OUT_DIR"

PROCESSED_FILES=()

echo "=== PASS 1: Hierarchical profiles (preset_filament.json in $BRAND/$MATERIAL/$PRINTER/$NOZZLE structure) ==="

find "$SRC_DIR" -type f -name "preset_filament.json" | while IFS= read -r filepath; do
    # Skip output dir
    [[ "$filepath" == "$OUT_DIR"* ]] && continue

    rel="${filepath#$SRC_DIR/}"
    IFS='/' read -ra parts <<< "$rel"

    # Need at least BRAND/MATERIAL/PRINTER/NOZZLE/filename = 5 parts
    [[ "${#parts[@]}" -lt 5 ]] && continue

    brand="${parts[0]}"
    material="${parts[1]}"
    printertype="${parts[2]}"
    nozzlesize="${parts[3]}"

    if ! matches_printer "$printertype"; then
        continue
    fi

    brand_s="$(sanitize "$brand")"
    material_s="$(sanitize "$material")"
    printer_s="$(sanitize "$printertype")"
    nozzle_s="$(sanitize "$nozzlesize")"

    outname="${brand_s}_${material_s}_${printer_s}_${nozzle_s}.json"

    cp "$filepath" "$OUT_DIR/$outname"
    echo "Copied: $outname"
done

echo ""
echo "=== PASS 2: Flat named profiles (brand/material files with printer in filename) ==="

find "$SRC_DIR" -mindepth 2 -maxdepth 2 -type f -name "*.json" | while IFS= read -r filepath; do
    [[ "$filepath" == "$OUT_DIR"* ]] && continue

    filename=$(basename "$filepath")
    [[ "$filename" == "preset_filament.json" ]] && continue
    [[ "$filename" == *"bundle_structure"* ]] && continue

    brand_dir=$(basename "$(dirname "$filepath")")

    if matches_printer "$filename"; then
        nozzle="$(extract_nozzle "$filename")"

        brand_s="$(sanitize "$brand_dir")"
        # Strip printer/nozzle noise from material name
        material="$filename"
        material="${material%.json}"
        for pat in "${PATTERNS[@]}"; do
            material="${material//$pat/}"
            material="${material//${pat,,}/}"
        done
        material="${material//@Bambu Lab/}"
        material="${material//@BBL/}"
        material="${material//0.4 nozzle/}"
        material="${material//0.6 nozzle/}"
        material="${material//0.2 nozzle/}"
        material="${material//0.8 nozzle/}"
        material="${material//nozzle/}"
        material="$(sanitize "$material")"
        # Collapse repeated underscores and trim
        material="$(echo "$material" | sed 's/_\+/_/g; s/^_//; s/_$//')"

        outname="${brand_s}_${material}_${PRINTER_ARG}_${nozzle}.json"
        cp "$filepath" "$OUT_DIR/$outname"
        echo "Copied: $outname"
    fi
done

echo ""
echo "=== PASS 3: Fallback - generic profiles with no printer in filename ==="
echo "    (base profiles, @base files, and files with no printer tag)"

find "$SRC_DIR" -mindepth 2 -maxdepth 2 -type f -name "*.json" | while IFS= read -r filepath; do
    [[ "$filepath" == "$OUT_DIR"* ]] && continue

    filename=$(basename "$filepath")
    [[ "$filename" == "preset_filament.json" ]] && continue
    [[ "$filename" == *"bundle_structure"* ]] && continue

    # Skip if it mentions ANY known printer explicitly - those were handled or intentionally excluded
    known_printers="A1M\|A1_mini\|A1 mini\|A1\b\|P1P\|P1S\|X1C\|X1_Carbon\|X1 Carbon\|X1E\|X1\b\|P2S\|H2C\|H2D\|H2S\|Bambu\|BBL\|Qidi"
    if echo "$filename" | grep -qi "$known_printers"; then
        continue
    fi

    brand_dir=$(basename "$(dirname "$filepath")")
    brand_s="$(sanitize "$brand_dir")"

    material="${filename%.json}"
    material="$(sanitize "$material")"
    material="$(echo "$material" | sed 's/_\+/_/g; s/^_//; s/_$//')"

    outname="${brand_s}_${material}_${PRINTER_ARG}_generic.json"
    cp "$filepath" "$OUT_DIR/$outname"
    echo "Copied: $outname"
done

echo ""
echo "Done. $(ls "$OUT_DIR" | wc -l) files in $OUT_DIR"
