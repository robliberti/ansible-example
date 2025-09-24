#!/bin/bash
# upload-to-s3.sh - Upload Tomcat configurations to S3
# Usage: ./scripts/upload-to-s3.sh [-c CUSTOMER] [-p PRODUCT] [-e ENVIRONMENT] [-t TARGET] [-b BUCKET] [-P PROFILE] [-v VERSION]

# Get script directory and project root (one level up)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
CUSTOMER="GSF"
PRODUCT="dakota"
ENVIRONMENT="prod"
TARGET="iseries"
BUCKET="bfc-tomcat-configs"
PROFILE="bfc-tomcat-github-uploader"
VERSION=""

# Parse command line options
while getopts "c:p:e:t:b:P:v:" opt; do
  case ${opt} in
    c ) CUSTOMER=$OPTARG ;;
    p ) PRODUCT=$OPTARG ;;
    e ) ENVIRONMENT=$OPTARG ;;
    t ) TARGET=$OPTARG ;;
    b ) BUCKET=$OPTARG ;;
    P ) PROFILE=$OPTARG ;;
    v ) VERSION=$OPTARG ;;
    \? ) 
      echo "Usage: $0 [-c CUSTOMER] [-p PRODUCT] [-e ENVIRONMENT] [-t TARGET] [-b BUCKET] [-P PROFILE] [-v VERSION]"
      echo "  -v VERSION: Product version (e.g., 7.9 for Dakota)"
      exit 1
      ;;
  esac
done

# Change to project root directory
cd "$PROJECT_ROOT"

# Set default version if not provided
if [ -z "$VERSION" ]; then
  case $PRODUCT in
    dakota) VERSION="7.9" ;;
    selectprime) VERSION="3.5" ;;
    api) VERSION="2.0" ;;
    trax) VERSION="1.0" ;;
    *) VERSION="latest" ;;
  esac
fi

echo "Uploading $PRODUCT v$VERSION configs for $CUSTOMER to $BUCKET ($ENVIRONMENT/$TARGET)..."

# Determine if we should use AWS profile or environment variables
AWS_CMD="aws s3 cp"
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
  # Running in GitHub Actions or environment with AWS credentials set
  echo "Using AWS credentials from environment variables"
  AWS_PROFILE_ARG=""
else
  # Running locally with AWS profile
  echo "Using AWS profile: $PROFILE"
  AWS_PROFILE_ARG="--profile $PROFILE"
fi

# Check for hierarchical output structure first
if [ -d "output/$PRODUCT/v$VERSION/$CUSTOMER" ]; then
  echo "Found hierarchical output structure. Uploading from output/$PRODUCT/v$VERSION/$CUSTOMER/"
  OUTPUT_PATH="output/$PRODUCT/v$VERSION/$CUSTOMER"
  S3_PATH="s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER/configs/"
# Fall back to old structure if hierarchical structure doesn't exist
elif [ -d "output/$PRODUCT/$CUSTOMER" ]; then
  echo "Found legacy output structure. Uploading from output/$PRODUCT/$CUSTOMER/"
  OUTPUT_PATH="output/$PRODUCT/$CUSTOMER"
  S3_PATH="s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER/configs/"
else
  echo "Error: Directory output/$PRODUCT/v$VERSION/$CUSTOMER or output/$PRODUCT/$CUSTOMER not found!"
  exit 1
fi

# Upload individual files from output directory
if [ -d "$OUTPUT_PATH" ]; then
  echo "Uploading individual files to $S3_PATH..."
  if [ -n "$AWS_PROFILE_ARG" ]; then
    aws s3 cp "$OUTPUT_PATH/" "$S3_PATH" --recursive $AWS_PROFILE_ARG
  else
    aws s3 cp "$OUTPUT_PATH/" "$S3_PATH" --recursive
  fi
  
  if [ $? -eq 0 ]; then
    echo "Individual files uploaded successfully"
  else
    echo "Error: Failed to upload individual files"
    exit 1
  fi
fi

# Upload bundled artifact if it exists - HIERARCHICAL BUNDLE HANDLING
CUSTOMER_LOWER=$(echo "$CUSTOMER" | tr '[:upper:]' '[:lower:]')
CUSTOMER_UPPER=$(echo "$CUSTOMER" | tr '[:lower:]' '[:upper:]')

# Try multiple possible bundle file locations
POSSIBLE_BUNDLES=(
  "temp_artifacts/$PRODUCT/v$VERSION/$CUSTOMER_LOWER-$PRODUCT-configs.zip"
  "temp_artifacts/$PRODUCT/v$VERSION/${CUSTOMER_LOWER}-${PRODUCT}-complete.zip"
  "complete_packages/$PRODUCT/v$VERSION/$CUSTOMER_LOWER/$CUSTOMER_LOWER-$PRODUCT-complete.zip"
  # Legacy paths for backward compatibility
  "temp_artifacts/${CUSTOMER_LOWER}-${PRODUCT}-v${VERSION}-configs.zip"
  "temp_artifacts/${CUSTOMER_LOWER}-${PRODUCT}-v${VERSION}-complete.zip"
)

BUNDLE_FOUND=false
for BUNDLE_PATH in "${POSSIBLE_BUNDLES[@]}"; do
  if [ -f "$BUNDLE_PATH" ]; then
    echo "Found bundle: $BUNDLE_PATH"
    
    # Determine appropriate S3 path based on bundle type
    if [[ "$BUNDLE_PATH" == *"-configs.zip" ]]; then
      S3_BUNDLE_PATH="s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER_UPPER/configs.zip"
      echo "Uploading config bundle to: $S3_BUNDLE_PATH"
    elif [[ "$BUNDLE_PATH" == *"-complete.zip" ]]; then
      S3_BUNDLE_PATH="s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER_UPPER/complete/$CUSTOMER_LOWER-$PRODUCT-complete.zip"
      echo "Uploading complete bundle to: $S3_BUNDLE_PATH"
    else
      S3_BUNDLE_PATH="s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER_UPPER/bundle.zip"
      echo "Uploading generic bundle to: $S3_BUNDLE_PATH"
    fi
    
    # Upload with consistent naming (always use uppercase customer in S3 path)
    if [ -n "$AWS_PROFILE_ARG" ]; then
      aws s3 cp "$BUNDLE_PATH" "$S3_BUNDLE_PATH" $AWS_PROFILE_ARG
    else
      aws s3 cp "$BUNDLE_PATH" "$S3_BUNDLE_PATH"
    fi
    
    if [ $? -eq 0 ]; then
      echo "Bundle uploaded successfully to $S3_BUNDLE_PATH"
      BUNDLE_FOUND=true
    else
      echo "Warning: Failed to upload bundle $BUNDLE_PATH"
    fi
  fi
done

if [ "$BUNDLE_FOUND" = false ]; then
  echo "Warning: No bundle files found. Checked:"
  for BUNDLE_PATH in "${POSSIBLE_BUNDLES[@]}"; do
    echo "  - $BUNDLE_PATH"
  done
fi

echo "Upload complete!"