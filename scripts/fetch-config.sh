#!/bin/bash
# fetch-config.sh - Download Tomcat configurations from S3
# Usage: ./scripts/fetch-config.sh [-c CUSTOMER] [-p PRODUCT] [-e ENVIRONMENT] [-t TARGET] [-b BUCKET] [-P PROFILE] [-o OUTPUT_DIR] [-B] [-v VERSION]

# Get script directory and project root (one level up)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
CUSTOMER="GSF"
PRODUCT="dakota"
ENVIRONMENT="prod"
TARGET="iseries"
BUCKET="bfc-tomcat-configs"
PROFILE="bfc-tomcat-app-reader"
BUNDLE=false
OUTPUT_DIR="downloaded-configs"
VERSION=""

# Parse command line options
while getopts "c:p:e:t:b:P:o:Bv:" opt; do
  case ${opt} in
    c ) CUSTOMER=$OPTARG ;;
    p ) PRODUCT=$OPTARG ;;
    e ) ENVIRONMENT=$OPTARG ;;
    t ) TARGET=$OPTARG ;;
    b ) BUCKET=$OPTARG ;;
    P ) PROFILE=$OPTARG ;;
    o ) OUTPUT_DIR=$OPTARG ;;
    B ) BUNDLE=true ;;
    v ) VERSION=$OPTARG ;;
    \? ) 
      echo "Usage: $0 [-c CUSTOMER] [-p PRODUCT] [-e ENVIRONMENT] [-t TARGET] [-b BUCKET] [-P PROFILE] [-o OUTPUT_DIR] [-B] [-v VERSION]"
      echo "-B flag downloads the bundled zip instead of individual files"
      echo "-v VERSION: Product version (e.g., 7.9 for Dakota)"
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

echo "Fetching $PRODUCT v$VERSION configs for $CUSTOMER from $BUCKET ($ENVIRONMENT/$TARGET)..."

# Determine if we should use AWS profile or environment variables
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
  # Running in GitHub Actions or environment with AWS credentials set
  AWS_PROFILE_ARG=""
else
  # Running locally with AWS profile
  AWS_PROFILE_ARG="--profile $PROFILE"
fi

if [ "$BUNDLE" = true ]; then
  # Download the bundled zip - HIERARCHICAL BUNDLE HANDLING
  mkdir -p "$OUTPUT_DIR"
  
  CUSTOMER_LOWER=$(echo "$CUSTOMER" | tr '[:upper:]' '[:lower:]')
  CUSTOMER_UPPER=$(echo "$CUSTOMER" | tr '[:lower:]' '[:upper:]')
  
  # First, try to download from hierarchical structure - complete package
  BUNDLE_S3_PATH="s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER_UPPER/complete/${CUSTOMER_LOWER}-${PRODUCT}-complete.zip"
  BUNDLE_LOCAL_PATH="$OUTPUT_DIR/${CUSTOMER_LOWER}-${PRODUCT}-v${VERSION}-complete.zip"
  
  echo "Attempting to download complete bundle from: $BUNDLE_S3_PATH"
  
  if [ -n "$AWS_PROFILE_ARG" ]; then
    aws s3 cp "$BUNDLE_S3_PATH" "$BUNDLE_LOCAL_PATH" $AWS_PROFILE_ARG
  else
    aws s3 cp "$BUNDLE_S3_PATH" "$BUNDLE_LOCAL_PATH"
  fi
  
  # If complete package not found, try config bundle
  if [ $? -ne 0 ]; then
    echo "Complete bundle not found, trying config bundle..."
    BUNDLE_S3_PATH="s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER_UPPER/configs.zip"
    BUNDLE_LOCAL_PATH="$OUTPUT_DIR/${CUSTOMER_LOWER}-${PRODUCT}-v${VERSION}-configs.zip"
    
    echo "Attempting to download config bundle from: $BUNDLE_S3_PATH"
    
    if [ -n "$AWS_PROFILE_ARG" ]; then
      aws s3 cp "$BUNDLE_S3_PATH" "$BUNDLE_LOCAL_PATH" $AWS_PROFILE_ARG
    else
      aws s3 cp "$BUNDLE_S3_PATH" "$BUNDLE_LOCAL_PATH"
    fi
  fi
  
  # If the hierarchical bundles fail, try the legacy bundle path as fallback
  if [ $? -ne 0 ]; then
    echo "Hierarchical bundles not found, trying legacy bundle path..."
    # Legacy bundle path
    BUNDLE_S3_PATH="s3://$BUCKET/environment/$ENVIRONMENT/$TARGET/bundles/$CUSTOMER_UPPER/${CUSTOMER_LOWER}-${PRODUCT}-configs.zip"
    BUNDLE_LOCAL_PATH="$OUTPUT_DIR/${CUSTOMER_LOWER}-${PRODUCT}-configs.zip"
    
    echo "Attempting to download bundle from legacy path: $BUNDLE_S3_PATH"
    
    if [ -n "$AWS_PROFILE_ARG" ]; then
      aws s3 cp "$BUNDLE_S3_PATH" "$BUNDLE_LOCAL_PATH" $AWS_PROFILE_ARG
    else
      aws s3 cp "$BUNDLE_S3_PATH" "$BUNDLE_LOCAL_PATH"
    fi
  fi
  
  if [ $? -eq 0 ]; then
    echo "Bundle downloaded to $BUNDLE_LOCAL_PATH"
    
    # Optionally unzip
    read -p "Do you want to extract the bundle? (y/n): " extract
    if [[ $extract == "y" || $extract == "Y" ]]; then
      mkdir -p "$OUTPUT_DIR/extracted/$PRODUCT/v$VERSION/$CUSTOMER_LOWER"
      unzip -o "$BUNDLE_LOCAL_PATH" -d "$OUTPUT_DIR/extracted/$PRODUCT/v$VERSION/$CUSTOMER_LOWER"
      echo "Extracted to $OUTPUT_DIR/extracted/$PRODUCT/v$VERSION/$CUSTOMER_LOWER/"
    fi
  else
    echo "Error: Failed to download bundle!"
    echo "Checked paths:"
    echo "  - s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER_UPPER/complete/${CUSTOMER_LOWER}-${PRODUCT}-complete.zip"
    echo "  - s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER_UPPER/configs.zip"
    echo "  - s3://$BUCKET/environment/$ENVIRONMENT/$TARGET/bundles/$CUSTOMER_UPPER/${CUSTOMER_LOWER}-${PRODUCT}-configs.zip"
    
    # Try to list what's actually available in the hierarchical structure
    echo "Available files for $CUSTOMER_UPPER $PRODUCT v$VERSION:"
    if [ -n "$AWS_PROFILE_ARG" ]; then
      aws s3 ls "s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER_UPPER/" --recursive $AWS_PROFILE_ARG || echo "No files found in hierarchical structure"
    else
      aws s3 ls "s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER_UPPER/" --recursive || echo "No files found in hierarchical structure"
    fi
    
    # Also check legacy path
    echo "Available files in legacy structure:"
    if [ -n "$AWS_PROFILE_ARG" ]; then
      aws s3 ls "s3://$BUCKET/environment/$ENVIRONMENT/$TARGET/bundles/$CUSTOMER_UPPER/" $AWS_PROFILE_ARG || echo "No files found in legacy structure"
    else
      aws s3 ls "s3://$BUCKET/environment/$ENVIRONMENT/$TARGET/bundles/$CUSTOMER_UPPER/" || echo "No files found in legacy structure"
    fi
  fi
else
  # Download individual files
  mkdir -p "$OUTPUT_DIR/$PRODUCT/v$VERSION/$CUSTOMER"
  
  # First try hierarchical structure
  echo "Attempting to download from hierarchical structure..."
  if [ -n "$AWS_PROFILE_ARG" ]; then
    aws s3 cp "s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER/configs/" \
        "$OUTPUT_DIR/$PRODUCT/v$VERSION/$CUSTOMER/" --recursive $AWS_PROFILE_ARG
  else
    aws s3 cp "s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER/configs/" \
        "$OUTPUT_DIR/$PRODUCT/v$VERSION/$CUSTOMER/" --recursive
  fi
  
  # If hierarchical structure fails, try legacy structure
  if [ $? -ne 0 ]; then
    echo "Hierarchical structure not found, trying legacy structure..."
    if [ -n "$AWS_PROFILE_ARG" ]; then
      aws s3 cp "s3://$BUCKET/environment/$ENVIRONMENT/$TARGET/products/$PRODUCT/$CUSTOMER/" \
          "$OUTPUT_DIR/$PRODUCT/$CUSTOMER/" --recursive $AWS_PROFILE_ARG
    else
      aws s3 cp "s3://$BUCKET/environment/$ENVIRONMENT/$TARGET/products/$PRODUCT/$CUSTOMER/" \
          "$OUTPUT_DIR/$PRODUCT/$CUSTOMER/" --recursive
    fi
    
    if [ $? -eq 0 ]; then
      echo "Files downloaded to $OUTPUT_DIR/$PRODUCT/$CUSTOMER/"
    else
      echo "Error: Failed to download files from either structure!"
      echo "Tried paths:"
      echo "  - s3://$BUCKET/$ENVIRONMENT/$PRODUCT/v$VERSION/$CUSTOMER/configs/"
      echo "  - s3://$BUCKET/environment/$ENVIRONMENT/$TARGET/products/$PRODUCT/$CUSTOMER/"
    fi
  else
    echo "Files downloaded to $OUTPUT_DIR/$PRODUCT/v$VERSION/$CUSTOMER/"
  fi
fi

echo "Download complete!"