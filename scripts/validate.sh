#!/bin/bash
# validate.sh - Wrapper script for validating generated configuration files
# Usage: ./scripts/validate.sh [-g] [-c CUSTOMER] [-p PRODUCTS] [-v] [-V VERSIONS]

set -e

# Get script directory and project root (one level up)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
GENERATE=false
CUSTOMER="all"
PRODUCTS="all"
VERBOSE=false
VERSIONS=""

# Parse command line arguments
while getopts ":gc:p:vV:" opt; do
  case $opt in
    g)
      GENERATE=true
      ;;
    c)
      CUSTOMER=$OPTARG
      ;;
    p)
      PRODUCTS=$OPTARG
      if [ -z "$PRODUCTS" ]; then
        echo "Error: Option -p requires an argument." >&2
        echo "Usage: $0 [-g] [-c CUSTOMER] [-p PRODUCTS] [-v] [-V VERSIONS]"
        echo "  -g: Generate configurations before validation"
        echo "  -c CUSTOMER: Customer to validate (default: all)"
        echo "  -p PRODUCTS: Products to validate (comma-separated: dakota,selectprime,api,trax) (default: all)"
        echo "  -v: Verbose output"
        echo "  -V VERSIONS: Versions for products (format: dakota=7.9,selectprime=3.5,api=2.0,trax=1.0)"
        exit 1
      fi
      ;;
    v)
      VERBOSE=true
      ;;
    V)
      VERSIONS=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: $0 [-g] [-c CUSTOMER] [-p PRODUCTS] [-v] [-V VERSIONS]"
      echo "  -g: Generate configurations before validation"
      echo "  -c CUSTOMER: Customer to validate (default: all)"
      echo "  -p PRODUCTS: Products to validate (comma-separated: dakota,selectprime,api,trax) (default: all)"
      echo "  -v: Verbose output"
      echo "  -V VERSIONS: Versions for products (format: dakota=7.9,selectprime=3.5,api=2.0,trax=1.0)"
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Change to project root directory
cd "$PROJECT_ROOT"

# Check for Python and pip
if ! command -v python3 &> /dev/null; then
  echo "Error: Python 3 is not installed or not in PATH"
  exit 1
fi

if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
  echo "Error: pip is not installed or not in PATH"
  echo "Please install pip for Python 3"
  exit 1
fi

# Determine pip command (pip or pip3)
PIP_CMD="pip3"
if ! command -v pip3 &> /dev/null; then
  PIP_CMD="pip"
fi

# Ensure requirements are installed
echo "Checking Python dependencies..."
# Use a safer way to check for installed packages
LXML_INSTALLED=$($PIP_CMD list 2>/dev/null | grep -i lxml || true)
if [ -z "$LXML_INSTALLED" ]; then
  echo "Installing lxml Python package..."
  $PIP_CMD install lxml || {
    echo "Warning: Failed to install lxml. XML validation will be limited."
    echo "Please run: pip install lxml"
  }
fi

# Check if xmllint is installed
if ! command -v xmllint &> /dev/null; then
  echo "Warning: xmllint not found. XML validation will be limited."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "On macOS, install with: brew install libxml2"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "On Linux, install with: sudo apt-get install libxml2-utils"
  else
    echo "Please install libxml2-utils package for your platform."
  fi
fi

# Generate configurations if requested
if $GENERATE; then
  echo "Generating configurations for customer: $CUSTOMER, products: $PRODUCTS"
  
  GENERATE_CMD="$SCRIPT_DIR/generate.sh -c $CUSTOMER -p $PRODUCTS"
  
  if [ -n "$VERSIONS" ]; then
    GENERATE_CMD="$GENERATE_CMD -v $VERSIONS"
  fi
  
  eval "$GENERATE_CMD"
fi

# Validate configurations
VALIDATION_CMD="ansible-playbook $PROJECT_ROOT/ansible/playbooks/validate-configs.yml"

if [ -n "$CUSTOMER" ]; then
  VALIDATION_CMD="$VALIDATION_CMD -e customer=$CUSTOMER"
fi

if [ -n "$PRODUCTS" ]; then
  VALIDATION_CMD="$VALIDATION_CMD -e products=$PRODUCTS"
fi

if [ -n "$VERSIONS" ]; then
  VALIDATION_CMD="$VALIDATION_CMD -e versions=$VERSIONS"
fi

if $VERBOSE; then
  VALIDATION_CMD="$VALIDATION_CMD -e verbose=true -v"
fi

echo "Validating configurations for customer: $CUSTOMER, products: $PRODUCTS"
if [ -n "$VERSIONS" ]; then
  echo "Using versions: $VERSIONS"
else
  echo "Using default product versions"
fi

$VALIDATION_CMD