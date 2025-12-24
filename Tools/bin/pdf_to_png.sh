#!/bin/bash

# PDF to PNG Converter
# Converts each page of PDF(s) into PNG images at 300 DPI
# Creates a folder for each PDF using the PDF's name

set -uo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 <pdf_file1> [pdf_file2] [pdf_file3] ..."
    echo ""
    echo "Examples:"
    echo "  $0 document.pdf"
    echo "  $0 file1.pdf file2.pdf file3.pdf"
    echo "  $0 /path/to/pdfs/*.pdf"
    echo ""
    exit 1
}

# Function to check dependencies
check_dependencies() {
    if ! command -v pdftoppm &> /dev/null; then
        echo -e "${RED}Error: pdftoppm is not installed.${NC}"
        echo "Please install poppler-utils:"
        echo "  Ubuntu/Debian: sudo apt-get install poppler-utils"
        echo "  Fedora/RHEL:   sudo dnf install poppler-utils"
        echo "  Arch:          sudo pacman -S poppler"
        exit 1
    fi
}

# Function to convert a single PDF
convert_pdf() {
    local pdf_file="$1"

    # Check if file exists
    if [[ ! -f "$pdf_file" ]]; then
        echo -e "${RED}Error: File '$pdf_file' not found.${NC}"
        return 1
    fi

    # Check if it's a PDF
    if [[ ! "$pdf_file" =~ \.pdf$ ]]; then
        echo -e "${YELLOW}Warning: '$pdf_file' does not appear to be a PDF file. Skipping.${NC}"
        return 1
    fi

    # Get the directory and filename
    local pdf_dir=$(dirname "$pdf_file")
    local pdf_basename=$(basename "$pdf_file" .pdf)

    # Create output directory
    local output_dir="${pdf_dir}/${pdf_basename}"

    if [[ -d "$output_dir" ]]; then
        echo -e "${YELLOW}Warning: Directory '$output_dir' already exists.${NC}"
        read -p "Overwrite existing images? (y/N): " -n 1 -r < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping '$pdf_file'"
            return 0
        fi
    else
        mkdir -p "$output_dir"
    fi

    echo -e "${GREEN}Processing:${NC} $pdf_file"
    echo -e "${GREEN}Output directory:${NC} $output_dir"

    # Convert PDF to PNG images at 300 DPI
    # -png: output format
    # -r 300: resolution (DPI)
    # The output files will be named: basename-01.png, basename-02.png, etc.
    if pdftoppm -png -r 300 "$pdf_file" "$output_dir/page"; then
        local num_pages=$(ls -1 "$output_dir"/page-*.png 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ Success:${NC} Converted $num_pages page(s) to PNG"
        echo ""
    else
        echo -e "${RED}✗ Error:${NC} Failed to convert '$pdf_file'"
        return 1
    fi
}

# Main script
main() {
    # Check if any arguments provided
    if [[ $# -eq 0 ]]; then
        echo -e "${RED}Error: No PDF files specified.${NC}"
        echo ""
        usage
    fi

    # Check for dependencies
    check_dependencies

    echo "========================================="
    echo "PDF to PNG Converter (300 DPI)"
    echo "========================================="
    echo ""

    local total_files=$#
    local successful=0
    local failed=0

    # Process each PDF file
    for pdf_file in "$@"; do
        if convert_pdf "$pdf_file"; then
            ((successful++))
        else
            ((failed++))
        fi
    done

    # Summary
    echo "========================================="
    echo "Conversion Summary"
    echo "========================================="
    echo "Total files processed: $total_files"
    echo -e "${GREEN}Successful: $successful${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Failed: $failed${NC}"
    fi
}

# Run main function with all arguments
main "$@"
