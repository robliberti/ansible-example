#!/bin/bash
# generate.sh - Wrapper script for generating configuration files
# Usage: ./scripts/generate.sh [-c CUSTOMER] [-p PRODUCTS] [-e ENVIRONMENT] [-v VERSIONS]

set -e

# Get script directory and project root (one level up)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
CUSTOMER=""
PRODUCTS=""
ENVIRONMENT="prod"
VERSIONS=""

# Parse command line arguments
while getopts ":c:p:e:v:" opt; do
  case $opt in
    c)
      CUSTOMER=$OPTARG
      ;;
    p)
      PRODUCTS=$OPTARG
      ;;
    e)
      ENVIRONMENT=$OPTARG
      ;;
    v)
      VERSIONS=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: $0 [-c CUSTOMER] [-p PRODUCTS] [-e ENVIRONMENT] [-v VERSIONS]"
      echo "  -c CUSTOMER: Customer to generate (default: all)"
      echo "  -p PRODUCTS: Products to generate (comma-separated: dakota,selectprime,api,trax) (default: all)"
      echo "  -e ENVIRONMENT: Environment to generate for (prod, test, dev) (default: prod)"
      echo "  -v VERSIONS: Versions for products (format: dakota=7.9,selectprime=3.5,api=2.0,trax=1.0)"
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

# Check for Ansible
if ! command -v ansible-playbook &> /dev/null; then
  echo "Error: ansible-playbook is not installed or not in PATH"
  exit 1
fi

# Ensure output directory exists
echo "Ensuring output directory exists..."
mkdir -p output
chmod 777 output
ls -la output

# Debug playbook location and existence
echo "Checking for Ansible playbooks..."
ls -la "$PROJECT_ROOT/ansible/playbooks" || echo "Playbooks directory not found!"

# Check playbook content
echo "Checking main playbook content:"
if [ -f "$PROJECT_ROOT/ansible/playbooks/generate-configs.yml" ]; then
  head -n 20 "$PROJECT_ROOT/ansible/playbooks/generate-configs.yml"
  echo "..."
else
  echo "Main playbook file not found!"
fi

# Debug inventory
echo "Checking Ansible inventory..."
if [ -f "$PROJECT_ROOT/ansible/inventory/hosts" ]; then
  echo "Inventory file exists:"
  cat "$PROJECT_ROOT/ansible/inventory/hosts"
else
  echo "Inventory file not found, creating basic inventory..."
  mkdir -p "$PROJECT_ROOT/ansible/inventory"
  echo "[localhost]" > "$PROJECT_ROOT/ansible/inventory/hosts"
  echo "localhost ansible_connection=local" >> "$PROJECT_ROOT/ansible/inventory/hosts"
  echo "[customers]" >> "$PROJECT_ROOT/ansible/inventory/hosts"
  # Add customers from group_vars
  for customer_file in "$PROJECT_ROOT"/ansible/group_vars/*.yml; do
    if [ -f "$customer_file" ]; then
      customer_name=$(basename "$customer_file" .yml)
      echo "$customer_name" >> "$PROJECT_ROOT/ansible/inventory/hosts"
    fi
  done
  cat "$PROJECT_ROOT/ansible/inventory/hosts"
fi

# Check group_vars
echo "Checking group_vars files..."
if [ -d "$PROJECT_ROOT/ansible/group_vars" ]; then
  echo "Group vars directory exists. Files:"
  ls -la "$PROJECT_ROOT/ansible/group_vars"
  
  echo "Sample group_vars content (first file):"
  FIRST_GROUP_VAR=$(find "$PROJECT_ROOT/ansible/group_vars" -name "*.yml" | head -1)
  if [ -n "$FIRST_GROUP_VAR" ]; then
    head -n 20 "$FIRST_GROUP_VAR"
    echo "..."
  else
    echo "No group_vars files found!"
  fi
else
  echo "Group vars directory not found!"
fi

# Check templates
echo "Checking template files..."
if [ -d "$PROJECT_ROOT/ansible/templates" ]; then
  echo "Templates directory exists. Subdirectories:"
  ls -la "$PROJECT_ROOT/ansible/templates"
  
  for product in dakota selectprime api trax; do
    if [ -d "$PROJECT_ROOT/ansible/templates/$product" ]; then
      echo "$product templates:"
      ls -la "$PROJECT_ROOT/ansible/templates/$product"
      
      # Show sample template content
      FIRST_TEMPLATE=$(find "$PROJECT_ROOT/ansible/templates/$product" -name "*.j2" | head -1)
      if [ -n "$FIRST_TEMPLATE" ]; then
        echo "Sample $product template content ($(basename "$FIRST_TEMPLATE")):"
        head -n 10 "$FIRST_TEMPLATE"
        echo "..."
      fi
    else
      echo "$product template directory not found!"
    fi
  done
else
  echo "Templates directory not found!"
fi

# Generate configurations
echo "Setting up Ansible command..."

# Create a custom ansible.cfg file for debugging
echo "Creating debug ansible.cfg..."
cat > ansible.cfg << EOF
[defaults]
stdout_callback = debug
display_skipped_hosts = true
display_args_to_stdout = true
verbosity = 2

[callback_debug]
verbosity = 2
EOF

GENERATION_CMD="ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i $PROJECT_ROOT/ansible/inventory/hosts $PROJECT_ROOT/ansible/playbooks/generate-configs.yml"

if [ -n "$CUSTOMER" ]; then
  GENERATION_CMD="$GENERATION_CMD -e customer=$CUSTOMER"
fi

if [ -n "$PRODUCTS" ]; then
  GENERATION_CMD="$GENERATION_CMD -e products=$PRODUCTS"
fi

if [ -n "$ENVIRONMENT" ]; then
  GENERATION_CMD="$GENERATION_CMD -e environment=$ENVIRONMENT"
fi

if [ -n "$VERSIONS" ]; then
  GENERATION_CMD="$GENERATION_CMD -e versions=$VERSIONS"
fi

# Add project root as environment variable
GENERATION_CMD="$GENERATION_CMD -e project_root=$PROJECT_ROOT"

# Enable verbose output for debugging
GENERATION_CMD="$GENERATION_CMD -vvv"

echo "Generating configurations for customer: ${CUSTOMER:-all}, products: ${PRODUCTS:-all}, environment: $ENVIRONMENT"
if [ -n "$VERSIONS" ]; then
  echo "Using versions: $VERSIONS"
else
  echo "Using default product versions"
fi
echo "Running command: $GENERATION_CMD"

# Run the command and capture the output
ANSIBLE_OUTPUT=$(eval "$GENERATION_CMD" 2>&1)
ANSIBLE_EXIT_CODE=$?

echo "Ansible playbook exit code: $ANSIBLE_EXIT_CODE"
echo "Ansible output:"
echo "$ANSIBLE_OUTPUT"

# Check if any files were generated
echo "Checking generated files..."
find output -type f | sort
echo "Total files generated: $(find output -type f | wc -l)"

# Create test file in output to verify permissions
echo "Creating test file in output directory..."
echo "Test file" > output/test.txt
ls -la output/

# If no files were generated, check if product directories exist
if [ "$(find output -type f -not -name "test.txt" | wc -l)" -eq 0 ]; then
  echo "No files were generated (other than our test file). Checking if product directories were created..."
  find output -type d | sort
  
  echo "Checking Ansible playbook more thoroughly..."
  
  # Check product-specific playbooks
  for product in dakota selectprime api trax; do
    PRODUCT_PLAYBOOK="$PROJECT_ROOT/ansible/playbooks/generate-$product-configs.yml"
    if [ -f "$PRODUCT_PLAYBOOK" ]; then
      echo "$product playbook exists."
      echo "First 20 lines of $product playbook:"
      head -n 20 "$PRODUCT_PLAYBOOK"
      echo "..."
    else
      echo "$product playbook missing!"
    fi
  done
  
  # Try to manually create an output structure to test permissions
  echo "Testing manual file creation in output structure..."
  mkdir -p output/dakota/v7.9/GSF/BFCDakota/conf
  echo "<test>content</test>" > output/dakota/v7.9/GSF/BFCDakota/conf/test.xml
  ls -la output/dakota/v7.9/GSF/BFCDakota/conf/
fi

echo "Generation script completed."