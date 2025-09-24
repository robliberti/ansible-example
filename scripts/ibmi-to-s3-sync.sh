#!/QOpenSys/pkgs/bin/bash

DEBUG_MODE=1  # Set to 1 for debug mode

# Log output to a file and screen
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Ensure the script is run with required arguments
usage() {
    log "Usage:"
    log "  $0 <operation> [additional-params]"
    log
    log "Examples:"
    log "  $0 S3_SETUP                           # Set up S3cmd configuration"
    log "  $0 SYNC_FILES pattern bucket          # Sync files matching pattern to S3"
    log "  $0 SYNC_CONFIG [config-file]          # Sync using patterns in config file"
    log
    log "Operations:"
    log "  S3_SETUP    : Configure S3cmd for AWS access"
    log "  SYNC_FILES  : Sync files matching pattern to S3"
    log "  SYNC_CONFIG : Sync using patterns specified in a config file"
    log
    log "Parameters for SYNC_FILES:"
    log "  pattern     : File pattern to match (e.g., 'm-power.base.rls.*zip')"
    log "  bucket      : S3 bucket destination (e.g., 'dakota-java-assets/tomcat/base')"
    log
    log "Parameters for SYNC_CONFIG:"
    log "  [config-file] : Optional path to config file (default: /home/BFC/s3_sync_config.txt)"
    log "                  Format: source_pattern|s3_destination (one per line)"
    exit 1
}

#########
# General Functions:

# Function to log errors and exit
error_exit() {
    log "$1"
    exit 1
}

# Debug pause between steps if debug mode is on
debug_pause() {
    if [ "$DEBUG_MODE" -eq 1 ]; then
        read -p "Press Enter to continue..."
    fi
}

# Debug skip option if debug mode is on
debug_skip() {
    if [ "$DEBUG_MODE" -eq 1 ]; then
        # Ask the user if they want to skip the current step
        read -p "Do you want to skip step $((i + 1)) of ${#STEPS[@]}: $step_func $step_args? (y/n): " user_input
        if [[ "$user_input" =~ ^[Yy]$ ]]; then
            log "Skipping step $((i + 1)) of ${#STEPS[@]}: $step_func"
            return 0  # Indicate that the step should be skipped
        fi
    fi
    return 1  # Indicate that the step should not be skipped
}

# Install AWS tools
install_aws_tools() {
    # Save the current directory
    local current_dir=$(pwd)

    log "Ensuring pip installation..."
    # Check if pip is available
    if ! /QOpenSys/pkgs/bin/python3 -m pip --version &> /dev/null; then
        log "Pip not found, attempting to install it..."
        
        # Try the ensurepip module (this is more likely to work on IBM i)
        /QOpenSys/pkgs/bin/python3 -m ensurepip --default-pip
        
        # Verify pip was installed
        if ! /QOpenSys/pkgs/bin/python3 -m pip --version &> /dev/null; then
            log "ERROR: Failed to install pip. Continuing without it."
        else
            log "Pip installed successfully."
        fi
    else
        log "Pip is already installed."
    fi

    log "Checking python-dateutil installation..."
    if ! /QOpenSys/pkgs/bin/python3 -c "import dateutil" &> /dev/null; then
        # Only try to install if pip is available
        if /QOpenSys/pkgs/bin/python3 -m pip --version &> /dev/null; then
            log "Installing python-dateutil..."
            /QOpenSys/pkgs/bin/python3 -m pip install python-dateutil || {
                log "Failed to install python-dateutil. Continuing without it."
            }
        else
            log "Skipping python-dateutil installation (pip not available)."
        fi
    else
        log "python-dateutil is already installed."
    fi

    log "Ensuring /aws_tools directory exists..."
    if [ ! -d /aws_tools ]; then
        mkdir -p /aws_tools || {
            log "Failed to create /aws_tools directory."
            cd "$current_dir"
            return 1
        }
    else
        log "/aws_tools directory already exists."
    fi

    log "Changing to /aws_tools directory..."
    cd /aws_tools || {
        log "Failed to change to /aws_tools directory."
        cd "$current_dir"
        return 1
    }

    # Check if s3cmd is already installed
    log "Checking s3cmd download..."
    if [ ! -f s3cmd-2.4.0.zip ]; then
        log "Attempting to download s3cmd using curl..."
        if command -v curl &> /dev/null; then
            curl -L -o s3cmd-2.4.0.zip "https://sourceforge.net/projects/s3tools/files/s3cmd/2.4.0/s3cmd-2.4.0.zip" || {
                log "Failed to download s3cmd with curl."
                cd "$current_dir"
                return 1
            }
        else
            log "curl not found. Cannot download s3cmd."
            cd "$current_dir"
            return 1
        fi
    else
        log "s3cmd-2.4.0.zip already exists."
    fi

    log "Checking s3cmd extraction..."
    if [ ! -d s3cmd-2.4.0 ]; then
        if [ -f s3cmd-2.4.0.zip ]; then
            log "Unzipping s3cmd-2.4.0.zip..."
            if command -v unzip &> /dev/null; then
                unzip -o s3cmd-2.4.0.zip || {
                    log "Failed to unzip s3cmd-2.4.0.zip."
                    cd "$current_dir"
                    return 1
                }
            else
                log "unzip command not found. Cannot extract s3cmd."
                cd "$current_dir"
                return 1
            fi
        else
            log "s3cmd-2.4.0.zip not found. Cannot extract."
            cd "$current_dir"
            return 1
        fi
    else
        log "s3cmd-2.4.0 is already extracted."
    fi

    # Generate AES Key and IV using more portable methods
    log "Checking if AES encryption keys already exist..."

    if [ ! -f ~/.aes_key ]; then
        log "Generating new AES key..."
        if command -v openssl &> /dev/null; then
            openssl rand -hex 32 > ~/.aes_key || {
                # Fallback to a simpler method if openssl fails
                log "OpenSSL rand failed, using date-based key..."
                echo "$(date +%s%N | md5sum | head -c 32)" > ~/.aes_key
            }
            chmod 600 ~/.aes_key
        else
            log "OpenSSL not available. Using date-based key..."
            echo "$(date +%s%N | md5sum | head -c 32)" > ~/.aes_key
            chmod 600 ~/.aes_key
        fi
    else
        log "AES key already exists."
    fi

    if [ ! -f ~/.aes_iv ]; then
        log "Generating new AES IV..."
        if command -v openssl &> /dev/null; then
            openssl rand -hex 16 > ~/.aes_iv || {
                # Fallback to a simpler method if openssl fails
                log "OpenSSL rand failed, using date-based IV..."
                echo "$(date +%s%N | md5sum | head -c 16)" > ~/.aes_iv
            }
            chmod 600 ~/.aes_iv
        else
            log "OpenSSL not available. Using date-based IV..."
            echo "$(date +%s%N | md5sum | head -c 16)" > ~/.aes_iv
            chmod 600 ~/.aes_iv
        fi
    else
        log "AES IV already exists."
    fi

    log "AES encryption keys check completed."

    # Return to the original directory
    cd "$current_dir" || { 
        log "Failed to return to directory: $current_dir"; 
        return 1; 
    }

    log "Installation and setup completed successfully!"
    return 0
}

# Configure S3cmd
setup_s3cmd_config() {
    # Skip if credentials are already set
    if [[ -n "$S3_ACCESS_KEY" && -n "$S3_SECRET_KEY" ]]; then
        log "DEBUG: AWS credentials already loaded into global variables."
        return
    }

    log "Setting up AWS Tools and Configuring S3cmd..."

    # Ensure aws_tools are installed
    install_aws_tools

    # Check if config file already exists and is encrypted
    if [ -f ~/.s3cfg ] && grep -q "# ENCRYPTED" ~/.s3cfg; then
        log "~/.s3cfg already exists and credentials are encrypted. Decrypting for use..."
        decrypt_s3cfg
        return
    fi

    # Check if config exists but is not encrypted
    if [ -f ~/.s3cfg ] && grep -q "# DECRYPTED" ~/.s3cfg; then
        log "~/.s3cfg exists but is not encrypted."
        return
    fi

    # Prompt for credentials if config is missing or corrupted
    log "No valid S3cmd config found. Creating a new one."

    # Prompt user for AWS Access and Secret Keys
    read -rp "Enter your AWS Access Key: " AWS_ACCESS_KEY
    echo "Note: Your AWS Secret Key will not be visible while typing."
    read -rsp "Enter your AWS Secret Key: " AWS_SECRET_KEY
    echo

    # Debug: Print key lengths (do NOT print actual keys)
    log "Access Key Length: ${#AWS_ACCESS_KEY}"
    log "Secret Key Length: ${#AWS_SECRET_KEY}"

    # Create ~/.s3cfg
    log "Creating ~/.s3cfg file with provided credentials..."
    cat <<EOF > ~/.s3cfg
[default]
access_key = $AWS_ACCESS_KEY
secret_key = $AWS_SECRET_KEY
bucket_location = US
use_https = True
encrypt = False
multipart_chunk_size_mb = 15
# DECRYPTED
EOF

    chmod 600 ~/.s3cfg
    log "~/.s3cfg created successfully."

    # Encrypt the credentials immediately
    log "Encrypting credentials..."
    encrypt_s3cfg

    if grep -q "# ENCRYPTED" ~/.s3cfg; then
        log "AWS credentials encrypted successfully!"
    else
        log "Encryption failed. Check your configuration."
        exit 1
    fi
    
    # Decrypt for immediate use
    decrypt_s3cfg
}

# Encrypt a string using AES-256-CBC and Base64 encode
encrypt_string() {
    local PLAINTEXT=$1
    local CIPHERTEXT

    TMP_FILE=$(mktemp)
    echo -n "$PLAINTEXT" > "$TMP_FILE"
    CIPHERTEXT=$(openssl enc -aes-256-cbc -K "$(cat ~/.aes_key)" -iv "$(cat ~/.aes_iv)" -in "$TMP_FILE" | base64)
    rm -f "$TMP_FILE"

    echo "$CIPHERTEXT"
}

# Decrypt a Base64-encoded string using AES-256-CBC
decrypt_string() {
    local CIPHERTEXT=$1
    local PLAINTEXT

    TMP_FILE_ENC=$(mktemp)
    echo "$CIPHERTEXT" | base64 --decode > "$TMP_FILE_ENC"
    PLAINTEXT=$(openssl enc -d -aes-256-cbc -K "$(cat ~/.aes_key)" -iv "$(cat ~/.aes_iv)" -in "$TMP_FILE_ENC")
    rm -f "$TMP_FILE_ENC"

    echo "$PLAINTEXT"
}

# Encrypt sensitive keys in .s3cfg
encrypt_s3cfg() {
    if grep -q "# ENCRYPTED" ~/.s3cfg; then
        log "DEBUG: Keys already encrypted."
        return
    fi

    log "DEBUG: Starting S3CFG encryption process."

    # Extract keys
    ACCESS_KEY=$(grep "^access_key" ~/.s3cfg | sed 's/access_key *= *//')
    SECRET_KEY=$(grep "^secret_key" ~/.s3cfg | sed 's/secret_key *= *//')

    if [[ -z "$ACCESS_KEY" || -z "$SECRET_KEY" ]]; then
        log "ERROR: Access or Secret Key not found!"
        return 1
    fi

    ACCESS_KEY_ENC=$(encrypt_string "$ACCESS_KEY")
    SECRET_KEY_ENC=$(encrypt_string "$SECRET_KEY")

    # Update the .s3cfg file
    TMP_S3FILE=$(mktemp)

    sed -e "s|^access_key *=.*|access_key = $ACCESS_KEY_ENC|g" \
        -e "s|^secret_key *=.*|secret_key = $SECRET_KEY_ENC|g" \
        -e "s|# DECRYPTED|# ENCRYPTED|g" ~/.s3cfg > "$TMP_S3FILE"

    mv "$TMP_S3FILE" ~/.s3cfg
    log "DEBUG: Keys encrypted and saved."
}

# Decrypt sensitive keys in .s3cfg
decrypt_s3cfg() {
    if grep -q "# DECRYPTED" ~/.s3cfg; then
        log "DEBUG: Keys already decrypted."
        return
    fi

    log "DEBUG: Starting S3CFG decryption process."

    # Extract encrypted keys
    ACCESS_KEY_ENC=$(grep "^access_key" ~/.s3cfg | sed 's/access_key *= *//')
    SECRET_KEY_ENC=$(grep "^secret_key" ~/.s3cfg | sed 's/secret_key *= *//')

    if [[ -z "$ACCESS_KEY_ENC" || -z "$SECRET_KEY_ENC" ]]; then
        log "ERROR: Encrypted keys not found!"
        return 1
    fi

    ACCESS_KEY=$(decrypt_string "$ACCESS_KEY_ENC")
    SECRET_KEY=$(decrypt_string "$SECRET_KEY_ENC")

    # Update the .s3cfg file
    TMP_S3FILE=$(mktemp)

    sed -e "s|^access_key *=.*|access_key = $ACCESS_KEY|g" \
        -e "s|^secret_key *=.*|secret_key = $SECRET_KEY|g" \
        -e "s|# ENCRYPTED|# DECRYPTED|g" ~/.s3cfg > "$TMP_S3FILE"

    mv "$TMP_S3FILE" ~/.s3cfg
    log "DEBUG: Keys decrypted and saved."
}

# Function to check and install required packages
check_and_install_packages() {
    log "Checking and installing required packages: $@"
    
    # Function to attempt repairing the RPM database
    repair_rpm_db() {
        local repair_level=$1
        log "Attempting to repair RPM database (level $repair_level)..."
        
        if [ "$repair_level" -eq 1 ]; then
            # Basic repair - just rebuild the database
            log "Running basic RPM database rebuild..."
            /QOpenSys/pkgs/bin/rpm --rebuilddb
            return $?
        else
            # Advanced repair - remove lock files and rebuild
            log "Running advanced RPM database repair..."
            mkdir -p /tmp/rpmdb.backup.$(date +%Y%m%d%H%M%S)
            cp -a /QOpenSys/var/lib/rpm /tmp/rpmdb.backup.$(date +%Y%m%d%H%M%S)/
            log "RPM database backed up to /tmp/rpmdb.backup.$(date +%Y%m%d%H%M%S)"
            
            # Remove database lock files
            rm -f /QOpenSys/var/lib/rpm/__db*
            
            # Rebuild the database
            /QOpenSys/pkgs/bin/rpm --rebuilddb
            return $?
        fi
    }
    
    # Try to run yum command with automatic repair attempts
    run_yum_command() {
        local cmd="$1"
        local max_attempts=2
        local attempt=0
        
        while [ $attempt -lt $max_attempts ]; do
            log "Running: $cmd (attempt $((attempt+1)))"
            eval "$cmd" 2>&1
            
            if [ $? -eq 0 ]; then
                return 0  # Success
            fi
            
            # Check if the error is related to the RPM database
            if echo "$output" | grep -q "rpmdb open failed\|DB_RUNRECOVERY\|cannot open Packages"; then
                attempt=$((attempt+1))
                log "RPM database error detected. Attempt $attempt of $max_attempts"
                
                # Try to repair the database with escalating levels of intervention
                repair_rpm_db $attempt
                
                if [ $? -ne 0 ]; then
                    log "RPM database repair attempt $attempt failed"
                else
                    log "RPM database repair attempt $attempt completed, retrying command"
                fi
            else
                # Some other error occurred
                log "Command failed with a non-database error"
                return 1
            fi
        done
        
        log "Failed to execute command after $max_attempts repair attempts"
        return 1
    }
    
    # Check if packages are installed and install them if not
    for pkg in "$@"; do
        if ! command -v "$pkg" &> /dev/null; then
            log "$pkg not found. Installing..."
            
            # Try to install with automatic repair
            output=$(run_yum_command "/QOpenSys/pkgs/bin/yum install -y $pkg")
            
            if [ $? -eq 0 ]; then
                log "$pkg installed successfully."
            else
                log "Error: Failed to install $pkg. Manual intervention required." >&2
                log "Try running: /QOpenSys/pkgs/bin/rpm --rebuilddb" >&2
                log "Then: INSTALLP2PKG" >&2
                exit 1
            fi
        else
            log "$pkg is already installed."
        fi
    done
    
    log "All required packages have been verified."
}

# Create temp directory for file staging
create_staging_directory() {
    log "Creating staging directory for S3 uploads"
    
    # Create a unique timestamp for this run
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    STAGING_DIR="/tmp/s3_sync_${TIMESTAMP}"
    
    # Create the staging directory
    mkdir -p "$STAGING_DIR"
    
    if [ -d "$STAGING_DIR" ]; then
        log "Created staging directory: $STAGING_DIR"
    else
        error_exit "Failed to create staging directory: $STAGING_DIR"
    fi
}

# Find and copy local files matching a pattern to staging directory
find_and_stage_files() {
    local source_dir="$1"
    local pattern="$2"
    local s3_destination="$3"
    
    log "Finding files in $source_dir matching pattern: $pattern"
    
    # Create directory for this specific destination
    local dest_dir="$STAGING_DIR/$(basename "$s3_destination")"
    mkdir -p "$dest_dir"
    
    # Use find to locate files matching the pattern
    # Note: IBM i find may have different syntax, adjust if needed
    files_found=$(find "$source_dir" -type f -name "$pattern" 2>/dev/null)
    
    # Check if any files were found
    if [ -z "$files_found" ]; then
        log "No files found matching pattern: $pattern in $source_dir"
        return 0
    fi
    
    # Copy each found file to the staging directory
    file_count=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            cp "$file" "$dest_dir/" || {
                log "Warning: Failed to copy $file to staging directory"
                continue
            }
            file_count=$((file_count + 1))
        fi
    done <<< "$files_found"
    
    log "Copied $file_count files matching $pattern to staging directory"
    
    return 0
}

# Upload files from staging directory to S3 with size-based multipart upload
upload_to_s3() {
    local s3_destination="$1"
    
    log "Uploading files to S3 destination: $s3_destination"
    
    # Get the base directory for this upload
    local source_dir="$STAGING_DIR/$(basename "$s3_destination")"
    
    # Ensure the source directory exists and has files
    if [ ! -d "$source_dir" ] || [ -z "$(ls -A "$source_dir" 2>/dev/null)" ]; then
        log "Warning: No files to upload for destination: $s3_destination"
        return 0
    fi
    
    # Ensure S3cmd is configured
    setup_s3cmd_config
    
    # Upload files to S3, handling large files appropriately
    log "Uploading files from $source_dir to s3://$s3_destination"
    
    # Define size threshold for multipart uploads (in bytes)
    local MULTIPART_THRESHOLD=$((50 * 1024 * 1024))  # 50MB
    
    # Find all files in the source directory
    find "$source_dir" -type f | while read -r file; do
        # Get file size
        local file_size=$(stat -c "%s" "$file" 2>/dev/null || stat -f "%z" "$file" 2>/dev/null)
        local file_name=$(basename "$file")
        local relative_path=${file#$source_dir/}
        local s3_path="s3://$s3_destination/$relative_path"
        
        # Log file info
        log "Processing file: $file_name (Size: $(human_readable_size $file_size))"
        
        # Check if file exceeds threshold for multipart upload
        if [ "$file_size" -gt "$MULTIPART_THRESHOLD" ]; then
            log "Large file detected, using multipart upload for $file_name"
            
            # Use s3cmd with multipart parameters optimized for large files
            /aws_tools/s3cmd-2.4.0/s3cmd put \
                --multipart-chunk-size-mb=50 \
                --preserve \
                --acl-private \
                --stats \
                "$file" "$s3_path" || {
                log "Error: Failed multipart upload of $file_name to S3"
                continue
            }
            
            log "Successfully uploaded large file $file_name using multipart upload"
        else
            # Use standard upload for smaller files
            /aws_tools/s3cmd-2.4.0/s3cmd put \
                --preserve \
                --acl-private \
                "$file" "$s3_path" || {
                log "Error: Failed to upload $file_name to S3"
                continue
            }
            
            log "Successfully uploaded $file_name to S3"
        fi
    done
    
    log "Completed upload to S3 destination: $s3_destination"
    
    # Re-encrypt credentials
    encrypt_s3cfg
    
    return 0
}

# Convert file size to human-readable format
human_readable_size() {
    local size="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ "$size" -ge 1024 ] && [ "$unit" -lt 4 ]; do
        size=$(($size / 1024))
        unit=$(($unit + 1))
    done
    
    echo "$size ${units[$unit]}"
}


# Process a configuration file with multiple patterns and destinations
process_config_file() {
    local config_file="$1"
    
    log "Processing config file: $config_file"
    
    # Check if config file exists
    if [ ! -f "$config_file" ]; then
        error_exit "Configuration file not found: $config_file"
    }
    
    # Create staging directory
    create_staging_directory
    
    # Initialize line counter
    local line_count=0
    
    # Read each line from the config file
    while IFS='|' read -r source_info s3_destination || [ -n "$source_info" ]; do
        # Skip empty lines and comments
        if [[ -z "$source_info" || "$source_info" == \#* ]]; then
            continue
        fi
        
        # Parse source info into directory and pattern
        # Format can be either:
        # 1. /full/path/to/dir:pattern.* (with colon)
        # 2. pattern.* (uses SOURCE_DIR from environment)
        if [[ "$source_info" == *":"* ]]; then
            IFS=':' read -r source_dir pattern <<< "$source_info"
        else
            source_dir="$SOURCE_DIR"
            pattern="$source_info"
        fi
        
        # Skip if pattern or destination is empty
        if [[ -z "$pattern" || -z "$s3_destination" ]]; then
            log "Warning: Invalid line in config (missing pattern or destination): $source_info|$s3_destination"
            continue
        }
        
        line_count=$((line_count + 1))
        log "Processing config line $line_count: source_dir=$source_dir, pattern=$pattern, destination=$s3_destination"
        
        # Find and stage files
        find_and_stage_files "$source_dir" "$pattern" "$s3_destination"
    done < "$config_file"
    
    # Check if any valid lines were processed
    if [ $line_count -eq 0 ]; then
        log "Warning: No valid configuration lines found in $config_file"
        rm -rf "$STAGING_DIR"
        return 0
    fi
    
    # Upload all staged files to S3
    for dest_dir in "$STAGING_DIR"/*; do
        if [ -d "$dest_dir" ]; then
            s3_destination=$(basename "$dest_dir")
            upload_to_s3 "$s3_destination"
        fi
    done
    
    # Clean up staging directory
    rm -rf "$STAGING_DIR"
    
    log "Completed processing of configuration file with $line_count entries"
    
    return 0
}

# Sync a specific file pattern to S3
sync_files() {
    local pattern="$1"
    local s3_destination="$2"
    
    log "Syncing files matching pattern: $pattern to S3: $s3_destination"
    
    # Create staging directory
    create_staging_directory
    
    # Find and stage files
    find_and_stage_files "${SOURCE_DIR:-/BFCInstall/rob}" "$pattern" "$s3_destination"
    
    # Upload files to S3
    upload_to_s3 "$s3_destination"
    
    # Clean up staging directory
    rm -rf "$STAGING_DIR"
    
    log "File sync completed for pattern: $pattern"
    
    return 0
}

# Function to read the last completed step from the file
get_last_completed_step() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    echo 0
  fi
}

# Function to save the current step number
save_progress() {
  echo "$1" > "$STATE_FILE"
}

# Function to run the steps from where we left off
resume_steps() {
    LAST_COMPLETED_STEP=$(get_last_completed_step)

    for (( i = LAST_COMPLETED_STEP; i < ${#STEPS[@]}; i++ )); do
        step="${STEPS[$i]}"

        # Skip steps that are commented out (start with "#")
        if [[ "$step" =~ ^# ]]; then
            continue
        fi

        echo "" | tee -a "$LOG_FILE"

        # Split the step into function name and arguments
        step_func=$(echo "$step" | awk '{print $1}')
        step_args=$(echo "$step" | cut -d' ' -f2-)

        # Call debug_skip to check if the user wants to skip this step
        if debug_skip; then
            continue  # Skip this step and move to the next
        fi

        # Log and run the step with arguments safely expanded
        if [ -n "$step_args" ]; then
            log "Running step $((i + 1)) of ${#STEPS[@]}: $step_func $step_args"
            "$step_func" $step_args || {
                log "Error: Step '$step_func' failed with arguments '$step_args'." >&2
                exit 1
            }
        else
            log "Running step $((i + 1)) of ${#STEPS[@]}: $step_func"
            "$step_func" || {
                log "Error: Step '$step_func' failed." >&2
                exit 1
            }
        fi

        save_progress $((i + 1))  # Save progress after the step completes
        debug_pause
    done

    echo "All steps completed!"
}

##########
## main ##
##########

# Set up logging
LOCAL_DIR="/home/BFC"
LOG_FILE="$LOCAL_DIR/s3_sync_log.txt"
STATE_FILE="$LOCAL_DIR/s3_sync_state.txt"

# Create local directory if it doesn't exist
mkdir -p "$LOCAL_DIR" 2>/dev/null

# Default source directory if not specified
SOURCE_DIR=${SOURCE_DIR:-"/BFCInstall/rob"}

# Ensure the script is run with required arguments
if [[ $# -lt 1 ]]; then
    usage
fi

# Process the operation
OPERATION="${1^^}"  # Convert to uppercase
shift

# Global variables to hold credentials
S3_ACCESS_KEY=""
S3_SECRET_KEY=""

# Handle operation
case "$OPERATION" in
  S3_SETUP)
    log "Starting S3cmd configuration..."
    setup_s3cmd_config
    exit 0
    ;;
  SYNC_FILES)
    # Ensure required arguments are provided
    if [[ -z "$1" || -z "$2" ]]; then
        log "Error: SYNC_FILES operation requires pattern and destination arguments."
        usage
    fi
    
    PATTERN="$1"
    S3_DESTINATION="$2"
    
    # Define steps for file sync
    STEPS=(
        "check_and_install_packages curl unzip python3"
        "setup_s3cmd_config"
        "sync_files $PATTERN $S3_DESTINATION"
    )
    
    # Run steps
    resume_steps
    ;;
  SYNC_CONFIG)
    # Get config file path (use default if not provided)
    CONFIG_FILE=${1:-"/home/BFC/s3_sync_config.txt"}
    
    # Define steps for config-based sync
    STEPS=(
        "check_and_install_packages curl unzip python3"
        "setup_s3cmd_config"
        "process_config_file $CONFIG_FILE"
    )
    
    # Run steps
    resume_steps
    ;;
  *)
    error_exit "Invalid operation: $OPERATION. Use S3_SETUP, SYNC_FILES, or SYNC_CONFIG."
    ;;
esac

exit 0