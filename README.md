# bfc-java-config-automation (Ansible Version)

This repository automates the generation and deployment of Java configuration files across multiple products using environment-specific inputs and Ansible playbooks for template-driven workflows.

---

## 📁 Directory Structure

```
bfc-java-config-automation/
├── .github/workflows/
│   └── generate-configs.yml
├── ansible/
│   ├── group_vars/                       # Customer variables (replaces env/*.env)
│   │   ├── gsf.yml                       # GSF customer variables
│   │   ├── fdr.yml                       # FDR customer variables
│   │   ├── abc.yml                       # ABC customer variables 
│   │   ├── xyz.yml                       # XYZ customer variables
│   │   └── tpc.yml                       # TPC customer variables
│   ├── inventory/
│   │   └── hosts                         # Ansible inventory file
│   ├── playbooks/
│   │   ├── generate-configs.yml          # Main playbook
│   │   ├── validate-configs.yml          # Validation playbook
│   │   ├── generate-dakota-configs.yml   # Product-specific task files
│   │   ├── generate-selectprime-configs.yml
│   │   ├── generate-api-configs.yml
│   │   └── generate-trax-configs.yml
│   └── templates/                        # Jinja2 templates
│       ├── dakota/
│       │   ├── server.xml.j2             # Default template
│       │   ├── mrcjava.xml.j2            # Default template
│       │   ├── mrc-spring-context.xml.j2 # Default template
│       │   ├── v7.8/                     # Version-specific templates
│       │   │   └── server.xml.j2         # Dakota 7.8 specific template
│       │   ├── v7.9/                     # Version-specific templates
│       │   │   └── server.xml.j2         # Dakota 7.9 specific template
│       │   ├── v8.0/                     # Version-specific templates
│       │   │   └── server.xml.j2         # Dakota 8.0 specific template
│       │   └── v8.5/                     # Version-specific templates
│       │       └── server.xml.j2         # Dakota 8.5 specific template
│       ├── selectprime/
│       │   ├── server.xml.j2
│       │   ├── BFCConfigurationFile.xml.j2
│       │   ├── v1.0/                     # Version-specific templates
│       │   ├── v3.5/                     # Version-specific templates
│       │   └── v4.0/                     # Version-specific templates
│       ├── api/
│       │   ├── server-prod.xml.j2
│       │   ├── server-test.xml.j2
│       │   ├── v1.0/                     # Version-specific templates
│       │   ├── v2.0/                     # Version-specific templates
│       │   └── v3.0/                     # Version-specific templates
│       └── trax/
│           ├── server.xml.j2
│           ├── web.xml.j2
│           ├── v1.0/                     # Version-specific templates
│           └── v1.1/                     # Version-specific templates
├── docs/                                 # Documentation
│   └── s3-structure.md                   # S3 bucket structure documentation
├── scripts/                              # Utility scripts
│   ├── fetch-config.sh                   # Script to fetch configs from S3
│   ├── generate.sh                       # Generation wrapper script
│   ├── validate.sh                       # Validation wrapper script
│   └── upload-to-s3.sh                   # Script to upload configs to S3
├── output/                               # Generated configs (not committed)
│   ├── dakota/
│   │   ├── v7.8/                         # Version-specific outputs
│   │   │   ├── TPC/
│   │   │   └── GSF/
│   │   ├── v7.9/                         # Version-specific outputs
│   │   │   ├── GSF/
│   │   │   └── FDR/
│   │   └── v8.0/                         # Version-specific outputs
│   │       ├── GSF/
│   │       └── FDR/
│   ├── selectprime/
│   │   ├── v1.0/
│   │   ├── v3.5/
│   │   └── v4.0/
│   ├── api/
│   │   ├── v1.0/
│   │   ├── v2.0/
│   │   └── v3.0/
│   └── trax/
│       ├── v1.0/
│       └── v1.1/
├── downloaded-configs/                   # Downloaded configs (not committed)
├── Makefile                             # Build automation (optional)
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites:
```bash
# Install Ansible and dependencies
pip install ansible jinja2 pyyaml lxml

# Install system dependencies (for XML validation)
# macOS:
brew install libxml2

# Ubuntu/Debian:
sudo apt-get install libxml2-utils

# Install AWS CLI for S3 interaction
pip install awscli

# Make scripts executable
chmod +x scripts/*.sh
```

### Generate configs for a specific customer, product, and version:
```bash
# Generate Dakota v7.9 configs for GSF
ansible-playbook ansible/playbooks/generate-configs.yml -e "customer=gsf" -e "products=dakota" -e "versions=dakota=7.9"

# Generate Dakota v7.8 configs for TPC
ansible-playbook ansible/playbooks/generate-configs.yml -e "customer=tpc" -e "products=dakota" -e "versions=dakota=7.8"

# Generate SelectPrime v1.0 configs for FDR (using corrected default)
ansible-playbook ansible/playbooks/generate-configs.yml -e "customer=fdr" -e "products=selectprime" -e "versions=selectprime=1.0"

# Generate API v1.0 configs for GSF (using corrected default)
ansible-playbook ansible/playbooks/generate-configs.yml -e "customer=gsf" -e "products=api" -e "versions=api=1.0"

# Generate Trax v1.0 configs for FDR
ansible-playbook ansible/playbooks/generate-configs.yml -e "customer=fdr" -e "products=trax" -e "versions=trax=1.0"

# Generate multiple products with specific versions for a customer
ansible-playbook ansible/playbooks/generate-configs.yml -e "customer=gsf" -e "products=dakota,selectprime" -e "versions=dakota=8.0,selectprime=1.0"

# Generate configs for all customers with default versions
ansible-playbook ansible/playbooks/generate-configs.yml -e "customer=all"
```

### Using convenience scripts:
```bash
# Generate configs using wrapper script with version
./scripts/generate.sh -c gsf -p dakota -v dakota=7.9

# Generate configs for TPC with Dakota 7.8
./scripts/generate.sh -c tpc -p dakota -v dakota=7.8

# Generate configs for multiple products with versions
./scripts/generate.sh -c gsf -p dakota,selectprime -v dakota=8.0,selectprime=1.0

# Generate configs for all customers and products with default versions
./scripts/generate.sh -c all -p all
```

### Validate Configurations:
```bash
# Validate existing configs for a specific customer with version
./scripts/validate.sh -c gsf -V dakota=7.9

# Validate TPC Dakota 7.8 configs
./scripts/validate.sh -c tpc -p dakota -V dakota=7.8

# Validate existing configs for specific customer and products with versions
./scripts/validate.sh -c fdr -p dakota,selectprime -V dakota=7.9,selectprime=1.0

# Generate and validate configs with versions in one step
./scripts/validate.sh -g -c gsf -p dakota -V dakota=8.0

# Generate and validate all configs for all customers with default versions
./scripts/validate.sh -g -c all

# Validate all configs with verbose output
./scripts/validate.sh -v

# Validate specific customer with verbose output and version
./scripts/validate.sh -c fdr -p api -v -V api=1.0

# Validate with strict mode (fails on any validation errors)
./scripts/validate.sh -c gsf -p api -s -V api=1.0
```

### Interact with S3 Storage:
```bash
# Upload generated configs to S3 with version
./scripts/upload-to-s3.sh -c gsf -p dakota -e prod -v 7.9

# Upload TPC Dakota 7.8 configs to S3
./scripts/upload-to-s3.sh -c tpc -p dakota -e prod -v 7.8

# Upload config bundles to S3 with version
./scripts/upload-to-s3.sh -c gsf -p dakota -e prod -v 7.9

# Fetch individual configs from S3 with version
./scripts/fetch-config.sh -c GSF -p dakota -e prod -v 7.9 -P bfc-tomcat-app-reader

# Fetch TPC Dakota 7.8 configs from S3
./scripts/fetch-config.sh -c TPC -p dakota -e prod -v 7.8 -P bfc-tomcat-app-reader

# Fetch bundled configs from S3 with version
./scripts/fetch-config.sh -c GSF -p dakota -e prod -v 7.9 -B -P bfc-tomcat-app-reader
```

### Generate configs via GitHub Actions:
1. Go to **Actions** tab → **Generate and Validate Tomcat Configurations**
2. Click **Run workflow**
3. Fill in the **simplified 5-field form**:
   - **Customer**: Select customer (gsf, fdr, abc, xyz, tpc, all)
   - **Products**: Select products (dakota, selectprime, api, trax, all)
   - **Versions**: Enter specific versions (e.g., `dakota=7.8` for TPC, `dakota=7.9,selectprime=1.0` for multiple)
   - **Environment**: Select environment (prod, test, dev)
   - **Upload to S3**: Choose whether to upload artifacts
4. **Updated Defaults**:
   - Dakota: 7.9 (configurable, use `dakota=7.8` for TPC testing)
   - SelectPrime: 1.0 (corrected from 3.5)
   - API: 1.0 (corrected from 2.0)
   - Trax: 1.0 (unchanged)
5. Download generated artifacts

### Download Generated Configs:
- **Latest artifacts**: [Actions tab](../../actions/workflows/generate-configs.yml) → Click latest successful run → Download artifacts
- **Customer-specific**: Artifacts are named `{customer}-{product}-v{version}-configs` (e.g., `tpc-dakota-v7.8-configs.zip`, `gsf-dakota-v7.9-configs.zip`)
- **Direct link format**: `https://github.com/BFC-Software/bfc-java-config-automation/actions/runs/{RUN_ID}`

---

## 🔄 Version Support

The system now supports versioning for all products, allowing you to:
- Generate configurations for specific product versions
- Use version-specific templates and variables
- Handle libraries that change between versions
- Manage deprecated and new features across versions

### **Updated Version Defaults**:
- **Dakota**: 7.9 (primary version, configurable for testing)
- **SelectPrime**: 1.0 (corrected from previous 3.5 default)
- **API**: 1.0 (corrected from previous 2.0 default)
- **Trax**: 1.0 (unchanged)

### **TPC Testing Support**:
The workflow now supports TPC customer testing with Dakota 7.8:
```bash
# GitHub Actions: Use versions input "dakota=7.8"
# Command line: ./scripts/generate.sh -c tpc -p dakota -v dakota=7.8
# Ansible direct: ansible-playbook ... -e "customer=tpc" -e "versions=dakota=7.8"
```

### Version-Specific Features:

1. **Version-Specific Templates**:
   - Each product has default templates (used when no version-specific template exists)
   - Version-specific templates override the defaults when available:
     ```
     templates/dakota/
     ├── server.xml.j2         # Default template
     ├── v7.8/
     │   └── server.xml.j2     # Dakota 7.8-specific template (for TPC)
     ├── v7.9/
     │   └── server.xml.j2     # Dakota 7.9-specific template
     └── v8.0/
         └── server.xml.j2     # Dakota 8.0-specific template
     ```

2. **Version-Specific Variables**:
   - Environment files include version-specific sections:
     ```yaml
     # Dakota Configuration - Common
     dakota_http_port: 11300

     # Dakota Version-Specific Configuration
     dakota_versions:
       "7.8":
         db_schema: "dakota78"
         memory_max: "1024m"
         thread_count: 100
         libraries:
           - "dakotalib-core-7.8.jar"
           - "legacy-xml-parser.jar"
         legacy_xml_support: true
       "7.9":
         db_schema: "dakota79"
         memory_max: "1024m"
         thread_count: 100
         libraries:
           - "dakotalib-core-7.9.jar"
           - "legacy-xml-parser.jar"  # Legacy library removed in 8.0
         legacy_xml_support: true     # Deprecated in 8.0
       "8.0":
         db_schema: "dakota80"
         memory_max: "2048m"
         thread_count: 150
         libraries:
           - "dakotalib-core-8.0.jar"
           - "modern-xml-parser.jar"  # Replaces legacy-xml-parser.jar
         custom_feature_enabled: true # New in 8.0
     ```

3. **Library Management**:
   - Track required libraries for each version
   - Create placeholders for libraries in the output
   - Document library changes between versions

4. **Feature Flags**:
   - Enable/disable features based on version
   - Properly handle deprecated features
   - Add new features in newer versions

5. **Version Detection in Validation**:
   - Validate against version-specific requirements
   - Check for required version-specific settings
   - Handle both hierarchical and legacy structures

6. **Command Line Options**:
   - Specify versions for generation: `-v dakota=7.8,selectprime=1.0`
   - Specify versions for validation: `-V dakota=7.8,selectprime=1.0`
   - Specify version for S3 operations: `-v 7.8`

7. **S3 Directory Structure**:
   - Version-aware paths: `environment/prod/dakota/v7.8/TPC/`
   - Version-specific bundles: `environment/prod/dakota/v7.8/TPC/complete/tpc-dakota-complete.zip`

---

## 🔍 Configuration Validation

The validation system ensures generated configurations are correct and deployment-ready:

### **Validation Features:**
- ✅ **XML Well-formedness**: Validates all XML files are syntactically correct
- ✅ **Product-specific Port Validation**: Verifies correct ports are configured for each product
- ✅ **Environment-aware Validation**: Correctly validates PROD vs TEST environments for API
- ✅ **Schema Compliance**: Validates against XML schemas where applicable
- ✅ **Port Conflict Detection**: Checks for port conflicts across products and customers
- ✅ **Multi-customer Support**: Validates configurations across all customers
- ✅ **Warning Mode**: Records validation issues without failing the process
- ✅ **Strict Mode**: Optional mode to fail on any validation error
- ✅ **Version-Aware Validation**: Validates against version-specific requirements
- ✅ **Hierarchical Structure Support**: Validates both old and new directory structures

### **Validation Process:**
1. **File Discovery**: Finds all generated XML configuration files
2. **XML Syntax Check**: Uses `xmllint` to validate XML structure
3. **Environment Detection**: Identifies TEST vs PROD environments for API configs
4. **Product Validation**: Verifies product-specific configurations (ports, paths, etc.)
5. **Version Detection**: Identifies version-specific requirements
6. **Cross-validation**: Checks for conflicts between customers and products
7. **Reporting**: Provides detailed success/failure reports

### **Validation Commands:**
```bash
# Basic validation with version
./scripts/validate.sh -c fdr -p dakota -V dakota=7.9

# Validate TPC Dakota 7.8
./scripts/validate.sh -c tpc -p dakota -V dakota=7.8

# Validation with generation and version
./scripts/validate.sh -g -c gsf -p selectprime -V selectprime=1.0

# Verbose validation output with version
./scripts/validate.sh -c fdr -p dakota -v -V dakota=7.9

# Strict validation with version
./scripts/validate.sh -c gsf -p api -s -V api=1.0

# Validate all configurations with default versions
./scripts/validate.sh -c all
```

### **Validation Output:**
```
Validating configurations for customer: tpc, products: dakota
Versions: dakota=7.8
Found 3 XML files to validate
✅ XML well-formedness: All files valid
✅ Dakota HTTP port validation: Success
✅ Schema validation: All files compliant
✅ Port conflict check: No conflicts detected
✅ Version-specific validation: All version requirements met
All configuration files validated successfully! 3 files checked.
```

---

## 📦 S3 Storage Structure

The project uses an S3 bucket for storing and distributing configuration files with a version-aware hierarchical structure:

### **Bucket Layout:**
```
bfc-tomcat-configs/
├── prod/                               # Environment (prod, test, dev)
│   ├── dakota/                         # Product
│   │   ├── v7.8/                       # Version (for TPC)
│   │   │   └── TPC/                    # Customer
│   │   │       ├── configs/            # Individual config files
│   │   │       │   ├── server.xml
│   │   │       │   └── ...
│   │   │       └── complete/           # Complete deployment packages
│   │   │           └── tpc-dakota-complete.zip
│   │   ├── v7.9/                       # Version
│   │   │   ├── GSF/                    # Customer
│   │   │   │   ├── configs/            # Individual config files
│   │   │   │   │   ├── server.xml
│   │   │   │   │   └── ...
│   │   │   │   └── complete/           # Complete deployment packages
│   │   │   │       └── gsf-dakota-complete.zip
│   │   │   └── FDR/
│   │   │       └── ...
│   │   └── v8.0/
│   │       └── ...
│   ├── selectprime/
│   │   ├── v1.0/                       # Corrected default version
│   │   │   └── ...
│   │   ├── v3.5/
│   │   │   └── ...
│   │   └── v4.0/
│   │       └── ...
│   ├── api/
│   │   ├── v1.0/                       # Corrected default version
│   │   │   └── ...
│   │   ├── v2.0/
│   │   │   └── ...
│   │   └── v3.0/
│   │       └── ...
│   └── trax/
│       ├── v1.0/
│       │   └── ...
│       └── v1.1/
│           └── ...
├── test/                               # Test environment
│   └── ...                             # Same structure as prod
└── dev/                                # Development environment
    └── ...                             # Same structure as prod
```

### **AWS IAM Structure:**
The project uses the following IAM structure for S3 access:

| **Group**                          | **Policy**                     | **User**                      |
|-----------------------------------|--------------------------------|-------------------------------|
| `bfc-tomcat-deploy-group`         | `bfc-tomcat-s3-access`         | `bfc-tomcat-github-actions`   |
| `bfc-tomcat-github-actions-group` | `bfc-tomcat-s3-upload-only`    | `bfc-tomcat-github-uploader`  |
| `bfc-tomcat-application-group`    | `bfc-tomcat-s3-download-only`  | `bfc-tomcat-app-reader`       |

### **Using S3 CLI for Config Management:**
```bash
# Upload individual configuration files with version
aws s3 cp output/dakota/v7.9/GSF/ s3://bfc-tomcat-configs/prod/dakota/v7.9/GSF/configs/ \
    --recursive --profile bfc-tomcat-github-uploader

# Upload TPC Dakota 7.8 configs
aws s3 cp output/dakota/v7.8/TPC/ s3://bfc-tomcat-configs/prod/dakota/v7.8/TPC/configs/ \
    --recursive --profile bfc-tomcat-github-uploader

# Upload complete package
aws s3 cp gsf-dakota-v7.9-complete.zip s3://bfc-tomcat-configs/prod/dakota/v7.9/GSF/complete/ \
    --profile bfc-tomcat-github-uploader

# Download individual configuration files with version
aws s3 cp s3://bfc-tomcat-configs/prod/dakota/v7.9/GSF/configs/ ./downloaded-configs/dakota/v7.9/GSF/ \
    --recursive --profile bfc-tomcat-app-reader

# Download TPC Dakota 7.8 configs
aws s3 cp s3://bfc-tomcat-configs/prod/dakota/v7.8/TPC/configs/ ./downloaded-configs/dakota/v7.8/TPC/ \
    --recursive --profile bfc-tomcat-app-reader

# Download complete package
aws s3 cp s3://bfc-tomcat-configs/prod/dakota/v7.9/GSF/complete/gsf-dakota-complete.zip ./downloaded-configs/ \
    --profile bfc-tomcat-app-reader
```

### **Accessing Configuration Files:**
Using the utility scripts:
```bash
# Fetch individual configuration files with version
./scripts/fetch-config.sh -c GSF -p dakota -e prod -v 7.9 -P bfc-tomcat-app-reader

# Fetch TPC Dakota 7.8 configs
./scripts/fetch-config.sh -c TPC -p dakota -e prod -v 7.8 -P bfc-tomcat-app-reader

# Fetch bundled configuration files with version
./scripts/fetch-config.sh -c GSF -p dakota -e prod -v 7.9 -B -P bfc-tomcat-app-reader

# Upload individual generated configs with version
./scripts/upload-to-s3.sh -c GSF -p dakota -e prod -v 7.9 -P bfc-tomcat-github-uploader

# Upload TPC Dakota 7.8 configs
./scripts/upload-to-s3.sh -c TPC -p dakota -e prod -v 7.8 -P bfc-tomcat-github-uploader

# Upload bundled generated configs with version
./scripts/upload-to-s3.sh -c GSF -p dakota -e prod -v 7.9 -P bfc-tomcat-github-uploader
```

---

## 📝 How It Works

### 1. **Smart Change Detection**
The workflow intelligently processes only what's needed:
- **Group vars file changes**: Processes only affected customers
- **Template/playbook changes**: Processes ALL customers (affects everyone)
- **Manual triggers**: Processes only specified customer/products

### 2. **Simplified GitHub Actions Workflow**
The updated workflow features a **streamlined 5-field interface**:

#### **Updated Workflow Features**:
- ✅ **5 simplified input fields** (from previous 8) for better GitHub UI display
- ✅ **Corrected version defaults**: Dakota 7.9, SelectPrime/API/Trax 1.0
- ✅ **Version parsing logic** to handle combined version strings
- ✅ **Direct Ansible execution** instead of wrapper scripts for better control
- ✅ **TPC customer support** for Dakota 7.8 testing
- ✅ **All product artifact uploads** including TPC
- ✅ **Consistent version handling** throughout the workflow

#### **Input Fields**:
1. **Customer**: Select from dropdown (gsf, fdr, abc, xyz, tpc, all)
2. **Products**: Select from dropdown (dakota, selectprime, api, trax, all)
3. **Versions**: Text input for version overrides (e.g., `dakota=7.8`, `dakota=7.9,selectprime=1.0`)
4. **Environment**: Select environment (prod, test, dev)
5. **Upload to S3**: Boolean to control S3 upload

#### **Version Examples**:
- **TPC Dakota 7.8**: `dakota=7.8`
- **GSF Dakota 7.9**: `dakota=7.9` (or leave blank for default)
- **Multiple versions**: `dakota=7.9,selectprime=1.0,api=1.0`
- **Default versions**: Leave blank to use dakota=7.9,selectprime=1.0,api=1.0,trax=1.0

### 3. **Version-Aware Customer Configuration File**
Each customer has one `.yml` file containing ALL product configurations with version-specific sections:

```yaml
# ansible/group_vars/tpc.yml (example for TPC)
---
# Common Customer Information
client_id: "TPC"
client_id_lower: "tpc"
client_id_upper: "TPC"

# Dakota Configuration - Common
dakota_http_port: 11300
dakota_shutdown_port: 11385
dakota_redirect_port: 11383
dakota_ajp_port: 11389
dakota_tomcat_dirname: "Tomcat7082TPC11"

# Dakota Configuration - Version Specific
dakota_versions:
  "7.8":
    libraries_string: "BFCGLOGSFRF,DKT78.0,GSFSQL,GSFSQLPGM,QGPL,QTEMP"
    prod_libraries_string: "BFCGLOGSFRF,GSFMODS001,GSFMODS,GSFRF,GSFFIX001,DKT78.0,GSFFIX,GSFSQL,GSFSQLPGM,QGPL,QTEMP"
    test_libraries_string: "BFCGLOGSFRF,GSFTEMP,GSFFIXTST,GSFFIXTST1,DKT78.0,GSFFIX,GSFSQL,GSFSQLPGM,QGPL,QTEMP"
    program_library: "DKT78.0"  # Explicit program library for Dakota 7.8
    db_schema: "dakota78"
    memory_max: "1024m"
    thread_count: 100
    libraries:
      - "dakotalib-core-7.8.jar"
      - "legacy-xml-parser.jar"
    legacy_xml_support: true
  "7.9":
    libraries_string: "BFCGLOGSFRF,GSFFIX,GSFDKT,GSFSQL,GSFSQLPGM,QGPL,QTEMP"
    prod_libraries_string: "BFCGLOGSFRF,GSFMODS001,GSFMODS,GSFRF,GSFFIX001,GSFDKT001,GSFFIX,GSFDKT,GSFSQL,GSFSQLPGM,QGPL,QTEMP"
    test_libraries_string: "BFCGLOGSFRF,GSFTEMP,GSFFIXTST,GSFDKTTST,GSFTSTF,GSFFIXTST1,GSFDKTTST1,GSFFIX,GSFDKT,GSFSQL,GSFSQLPGM,QGPL,QTEMP"
    program_library: "GSFDKT"  # Explicit program library for Dakota 7.9
    db_schema: "dakota79"
    memory_max: "1024m"
    thread_count: 100
    libraries:
      - "dakotalib-core-7.9.jar"
      - "legacy-xml-parser.jar"  # Legacy library removed in 8.0
    legacy_xml_support: true     # Deprecated in 8.0

# SelectPrime Configuration - Common  
selectprime_http_port: 11600
selectprime_shutdown_port: 11605
selectprime_redirect_port: 11643
selectprime_ajp_port: 11609
selectprime_tomcat_dirname: "Tomcat7082TPCApps16"
selectprime_config_host: "127.0.0.1"
selectprime_program_library: "TPCAPPS"

# SelectPrime Configuration - Version Specific (corrected defaults)
selectprime_versions:
  "1.0":                                # Corrected default version
    thread_pool_size: 100
    app_features: "standard"
  "3.5":
    thread_pool_size: 100
    app_features: "standard"
  "4.0":
    thread_pool_size: 200
    app_features: "enhanced"
    new_feature_enabled: true
```

### 4. **Default and Version-Specific Templates**
Templates use both default and version-specific variations:

```
ansible/templates/dakota/
├── server.xml.j2             # Default template with version detection
├── mrcjava.xml.j2            # Default template
├── mrc-spring-context.xml.j2 # Default template
├── v7.8/                     # Version-specific templates (TPC)
│   ├── server.xml.j2         # Override for 7.8
│   └── legacy-config.xml.j2  # 7.8-only file
├── v7.9/                     # Version-specific templates
│   ├── server.xml.j2         # Override for 7.9
│   └── legacy-config.xml.j2  # 7.9-only file
└── v8.0/
    ├── server.xml.j2         # Override for 8.0
    └── enhanced-security.xml.j2  # 8.0-only file
```

Templates use product-specific variables and version-specific conditionals:

```xml
<!-- Default server.xml.j2 with version detection -->
<Server port="{{ dakota_shutdown_port }}" shutdown="SHUTDOWN">
  <!-- Security listener added in version 8.0+ -->
  {% if dakota_version_vars.enhanced_security is defined and dakota_version_vars.enhanced_security %}
  <Listener className="org.apache.catalina.security.SecurityListener" />
  {% endif %}
  
  <!-- Legacy XML support (only in 7.8 and 7.9) -->
  {% if dakota_version_vars.legacy_xml_support is defined and dakota_version_vars.legacy_xml_support %}
  <Listener className="org.apache.catalina.core.JasperListener" />
  {% endif %}
</Server>
```

### 5. **Version-Aware Generation**
Ansible uses version detection to select the appropriate templates:

```yaml
# Ansible task for Dakota with version support
- name: Check if version-specific template exists
  stat:
    path: "{{ project_root }}/ansible/templates/dakota/v{{ current_version }}/server.xml.j2"
  register: version_specific_template

- name: Generate server.xml (version-specific template)
  template:
    src: "{{ project_root }}/ansible/templates/dakota/v{{ current_version }}/server.xml.j2"
    dest: "{{ project_root }}/output/dakota/v{{ current_version }}/{{ client_id }}/BFCDakota/conf/server.xml"
  when: version_specific_template.stat.exists
    
- name: Generate server.xml (default template)
  template:
    src: "{{ project_root }}/ansible/templates/dakota/server.xml.j2"
    dest: "{{ project_root }}/output/dakota/v{{ current_version }}/{{ client_id }}/BFCDakota/conf/server.xml"
  when: not version_specific_template.stat.exists
```

### 6. **Version-Specific Library Handling**
Generate placeholders for version-specific libraries:

```yaml
- name: Create placeholder for version-specific libraries
  file:
    path: "{{ project_root }}/output/dakota/v{{ current_version }}/{{ client_id }}/BFCDakota/lib/{{ item }}"
    state: touch
    mode: '0644'
  loop: "{{ dakota_version_vars.libraries | default([]) }}"
  when: dakota_version_vars.libraries is defined
```

### 7. **Version-Aware Validation**
The validation process detects versions and validates accordingly:

```yaml
# Extract version for Dakota files
- name: Extract version for Dakota files (hierarchical)
  set_fact:
    file_version: "{{ item.path | regex_search('/dakota/v([^/]+)/', '\\1') }}"
  loop: "{{ dakota_server_files_hierarchical }}"
  register: dakota_hierarchical_versions
```

### 8. **Hierarchical S3 Structure**
Upload files to version-specific paths:

```bash
# Upload to version-specific S3 path
aws s3 cp "output/$product/v$version/$customer_upper/" \
    "s3://$bucket/$environment/$product/v$version/$customer_upper/configs/" \
    --recursive
```

---

## 📦 Artifact Structure

Generated artifacts are structured with version information:

```
tpc-dakota-v7.8-configs.zip:              # TPC-specific artifact
├── BFCDakota/
│   ├── conf/
│   │   ├── server.xml
│   │   ├── version.properties
│   │   └── catalina/localhost/mrcjava.xml
│   ├── lib/
│   │   ├── dakotalib-core-7.8.jar
│   │   ├── legacy-xml-parser.jar
│   │   └── README.md
│   └── m-power/mrcjava/WEB-INF/classes/mrc-spring-context.xml

gsf-dakota-v7.9-configs.zip:
├── BFCDakota/
│   ├── conf/
│   │   ├── server.xml
│   │   ├── version.properties
│   │   └── catalina/localhost/mrcjava.xml
│   ├── lib/
│   │   ├── dakotalib-core-7.9.jar
│   │   ├── legacy-xml-parser.jar
│   │   └── README.md
│   └── m-power/mrcjava/WEB-INF/classes/mrc-spring-context.xml

gsf-api-v1.0-configs.zip:                 # Using corrected default
├── Tomcat7082GSF12Int/
│   ├── PROD/
│   │   └── conf/
│   │       └── server.xml
│   └── TEST/
│       └── conf/
│           └── server.xml

tpc-dakota-v7.8-complete.zip:             # TPC complete package
├── tomcat/
│   ├── bin/
│   │   └── [all tomcat binaries]
│   ├── conf/
│   │   ├── server.xml             # Generated config
│   │   ├── version.properties     # Version info
│   │   └── [other config files]
│   ├── lib/
│   │   ├── dakotalib-core-7.8.jar # Version-specific library
│   │   ├── legacy-xml-parser.jar  # Version-specific library
│   │   └── [other tomcat libraries]
│   └── webapps/
│       └── [application files]
```

---

## 📋 Adding New Product Versions

1. **Update customer group_vars files:**
   ```yaml
   # Add version-specific section for the new version
   dakota_versions:
     "7.8":
       # TPC version config
     "7.9":
       # Existing version config
     "8.0":
       # Existing version config
     "8.5":  # New version
       db_schema: "dakota85"
       memory_max: "4096m"
       thread_count: 200
       libraries:
         - "dakotalib-core-8.5.jar"
         - "dakotalib-cloud-8.5.jar"  # New in 8.5
       cloud_ready: true
       containerized: true
   ```

2. **Create version-specific templates:**
   ```bash
   # Create version-specific template directory
   mkdir -p ansible/templates/dakota/v8.5
   
   # Create version-specific templates
   cp ansible/templates/dakota/server.xml.j2 ansible/templates/dakota/v8.5/
   
   # Add version-specific files
   touch ansible/templates/dakota/v8.5/cloud-config.xml.j2
   ```

3. **Test new version generation:**
   ```bash
   # Generate configs for the new version
   ./scripts/generate.sh -c gsf -p dakota -v dakota=8.5
   
   # Validate the generated configs
   ./scripts/validate.sh -c gsf -p dakota -V dakota=8.5
   ```

4. **Deploy version-specific configs:**
   ```bash
   # Upload to S3
   ./scripts/upload-to-s3.sh -c gsf -p dakota -e prod -v 8.5
   ```

---

## 📋 Adding New Products

1. **Create templates directory with version support:**
   ```bash
   mkdir -p ansible/templates/newproduct/v1.0
   ```

2. **Add template files:**
   ```bash
   # Default template
   echo '<Server port="{{ newproduct_http_port }}">' > ansible/templates/newproduct/server.xml.j2
   
   # Version-specific template
   echo '<Server port="{{ newproduct_http_port }}">' > ansible/templates/newproduct/v1.0/server.xml.j2
   ```

3. **Create generation task file:**
   ```bash
   cp ansible/playbooks/generate-dakota-configs.yml ansible/playbooks/generate-newproduct-configs.yml
   # Update template paths and product-specific variables
   ```

4. **Update main playbook:**
   ```yaml
   # Add to ansible/playbooks/generate-configs.yml
   - name: Generate NewProduct configs
     include_tasks: generate-newproduct-configs.yml
     vars:
       current_customer: "{{ item }}"
       current_version: "{{ version_dict.newproduct | default('1.0') }}"
     with_items: "{{ customer_list }}"
     when: "'newproduct' in products_list"
   ```

5. **Update customer group_vars files:**
   ```yaml
   # Add to all customer group_vars files (gsf.yml, fdr.yml, tpc.yml, etc.)
   # Common configuration
   newproduct_http_port: 14000
   newproduct_shutdown_port: 14005
   newproduct_tomcat_dirname: "TomcatGSFNewProduct14"
   
   # Version-specific configuration
   newproduct_versions:
     "1.0":
       memory_max: "1024m"
       thread_count: 100
       libraries:
         - "newproduct-core-1.0.jar"
     "2.0":
       memory_max: "2048m"
       thread_count: 150
       libraries:
         - "newproduct-core-2.0.jar"
       enhanced_feature: true
   ```

---

## 🎯 Key Benefits

✅ **Single Source of Truth**: One file per customer for all products  
✅ **No Variable Conflicts**: Product-specific prefixes (`dakota_*`, `selectprime_*`, etc.)  
✅ **Smart Processing**: Only processes changed customers for efficiency  
✅ **Version Support**: Generate configs for specific product versions  
✅ **Version-Specific Templates**: Override templates for specific versions  
✅ **Library Management**: Handle libraries that change between versions  
✅ **Feature Flags**: Enable/disable features based on version  
✅ **Hierarchical Structure**: Clean organization by product, version, and customer  
✅ **Complete Packages**: Generate deployable packages with correct libraries  
✅ **Proper Directory Structure**: Artifacts ready for direct deployment  
✅ **Simplified GitHub Workflow**: 5-field interface with corrected defaults  
✅ **TPC Support**: Dedicated support for TPC customer with Dakota 7.8  
✅ **Corrected Version Defaults**: SelectPrime/API/Trax now default to 1.0  
✅ **Direct Ansible Execution**: Better control and error handling in CI/CD  
✅ **Automated CI/CD**: GitHub Actions generates and deploys configs  
✅ **Resilient Workflow**: Continues with validation warnings rather than failing outright  
✅ **Environment Detection**: Correctly validates PROD vs TEST environments  
✅ **Scalable**: Easy to add new products, versions, and customers  
✅ **Template-Driven**: Consistent, maintainable configuration management  
✅ **Idempotent Execution**: Ansible tasks can be run multiple times safely  
✅ **Environment Support**: Multiple environments (prod/test) for products like API  
✅ **Improved Error Handling**: Better error reporting and recovery  
✅ **Advanced Template Features**: Jinja2 supports conditionals, loops, and filters  
✅ **Comprehensive Validation**: XML syntax, schema, and business rule validation  
✅ **Quality Assurance**: Ensures configurations are correct before deployment  
✅ **S3 Integration**: Automated deployment to S3 for distribution
✅ **Reliable Bundle Management**: Consistent naming and improved transfer between jobs
✅ **Improved AWS Credential Handling**: Fixed credential handling in upload/fetch scripts

---

## 🔧 Local Development

```bash
# Generate configs locally for a specific customer, product, and version
./scripts/generate.sh -c gsf -p dakota -v dakota=7.9

# Generate TPC Dakota 7.8 configs locally
./scripts/generate.sh -c tpc -p dakota -v dakota=7.8

# Generate and validate in one step with version
./scripts/validate.sh -g -c gsf -p dakota -V dakota=7.9

# Generate and validate TPC Dakota 7.8
./scripts/validate.sh -g -c tpc -p dakota -V dakota=7.8

# View generated files for specific version
find output/dakota/v7.9/ -name "*.xml" | head -5
find output/dakota/v7.8/ -name "*.xml" | head -5

# Test all products for a customer with corrected default versions
./scripts/generate.sh -c gsf -v dakota=7.9,selectprime=1.0,api=1.0,trax=1.0
./scripts/validate.sh -c gsf -V dakota=7.9,selectprime=1.0,api=1.0,trax=1.0

# Test TPC with Dakota 7.8
./scripts/generate.sh -c tpc -v dakota=7.8
./scripts/validate.sh -c tpc -V dakota=7.8

# Clean output directory
rm -rf output/

# Clean downloaded configs directory
rm -rf downloaded-configs/

# Use Makefile for common tasks
make generate CUSTOMER=gsf PRODUCTS=dakota VERSIONS=dakota=7.9
make generate CUSTOMER=tpc PRODUCTS=dakota VERSIONS=dakota=7.8
make validate CUSTOMER=gsf PRODUCTS=dakota VERSIONS=dakota=7.9
make validate CUSTOMER=tpc PRODUCTS=dakota VERSIONS=dakota=7.8
make all CUSTOMER=gsf VERSIONS=dakota=7.9,selectprime=1.0,api=1.0,trax=1.0
```

---

## 📚 File Naming Conventions

- **Group Vars files**: `ansible/group_vars/{customer}.yml` (e.g., `gsf.yml`, `fdr.yml`, `tpc.yml`)
- **Playbooks/Tasks**: `ansible/playbooks/generate-{product}-configs.yml` (e.g., `generate-dakota-configs.yml`)
- **Default Templates**: `ansible/templates/{product}/{file}.xml.j2` (e.g., `ansible/templates/dakota/server.xml.j2`)
- **Version-Specific Templates**: `ansible/templates/{product}/v{version}/{file}.xml.j2` (e.g., `ansible/templates/dakota/v7.8/server.xml.j2`, `ansible/templates/dakota/v7.9/server.xml.j2`)
- **API Templates**: `ansible/templates/api/server-{env}.xml.j2` (e.g., `server-prod.xml.j2`, `server-test.xml.j2`)
- **Output**: `output/{product}/v{version}/{customer}/` (e.g., `output/dakota/v7.8/TPC/`, `output/dakota/v7.9/GSF/`)
- **Artifacts**: `{customer}-{product}-v{version}-configs.zip` (e.g., `tpc-dakota-v7.8-configs.zip`, `gsf-dakota-v7.9-configs.zip`)
- **Complete Packages**: `{customer}-{product}-complete.zip` (e.g., `tpc-dakota-complete.zip`, `gsf-dakota-complete.zip`)
- **Scripts**: `scripts/generate.sh`, `scripts/validate.sh`, etc. (wrapper scripts for common operations)
- **S3 Structure**: 
  - Individual files: `{environment}/{product}/v{version}/{customer}/configs/` (e.g., `prod/dakota/v7.8/TPC/configs/`, `prod/dakota/v7.9/GSF/configs/`)
  - Complete packages: `{environment}/{product}/v{version}/{customer}/complete/` (e.g., `prod/dakota/v7.8/TPC/complete/`, `prod/dakota/v7.9/GSF/complete/`)
- **S3 Bundle Naming**: `{customer-lower}-{product}-complete.zip` (e.g., `tpc-dakota-complete.zip`, `gsf-dakota-complete.zip`) 

---

## 🐛 Troubleshooting

### Common Issues:

1. **Version-specific templates not used**:
   - Check if the version-specific template directory exists
   - Verify the template file has the same name as the default template
   - Ensure the version is correctly specified in the command line
   - Check the playbook for correct version parameter passing

2. **Version-specific variables not applied**:
   - Check if version-specific section exists in group_vars file
   - Verify version is passed correctly to the playbook
   - Check that templates correctly access version-specific variables
   - Ensure version dictionary is correctly created in the playbook

3. **TPC Dakota 7.8 generation issues**:
   - Verify TPC group_vars file exists (`ansible/group_vars/tpc.yml`)
   - Check that Dakota 7.8 version section is defined in TPC group_vars
   - Ensure version-specific template exists (`ansible/templates/dakota/v7.8/`)
   - Verify version parameter: `dakota=7.8`

4. **GitHub Actions workflow input issues**:
   - Ensure version input follows correct format: `dakota=7.8` (not `7.8`)
   - Check that customer is selected correctly (tpc for TPC testing)
   - Verify all 5 input fields are properly filled
   - Check workflow logs for version parsing errors

5. **Missing libraries for specific version**:
   - Check if libraries are defined in the version-specific section
   - Verify the library directory is being created
   - Ensure library placeholders are being generated

6. **Wrong version detected in validation**:
   - Check the regex pattern for version extraction
   - Verify the hierarchical directory structure is correct
   - Ensure version is passed correctly to the validation script

7. **S3 upload/download with versions not working**:
   - Check S3 path format includes version
   - Verify AWS credentials have access to the versioned paths
   - Ensure scripts correctly pass version parameter to AWS CLI
   - Check for version parameter in upload/fetch scripts

### Debug Commands:
```bash
# Test variable loading for version-specific variables
ansible -i ansible/inventory/hosts -m debug -a "var=dakota_versions" gsf
ansible -i ansible/inventory/hosts -m debug -a "var=dakota_versions" tpc

# Check version dictionary in main playbook
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/generate-configs.yml -e "customer=gsf" -e "products=dakota" -e "versions=dakota=7.9" --tags never -e "debug_vars=true"
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/generate-configs.yml -e "customer=tpc" -e "products=dakota" -e "versions=dakota=7.8" --tags never -e "debug_vars=true"

# Test version-specific template existence
ls -la ansible/templates/dakota/v7.8/
ls -la ansible/templates/dakota/v7.9/

# Check generated output structure with versions
find output/ -type f -name "*.xml" | grep "v7.8" | sort
find output/ -type f -name "*.xml" | grep "v7.9" | sort

# Check version properties file
cat output/dakota/v7.8/TPC/BFCDakota/conf/version.properties
cat output/dakota/v7.9/GSF/BFCDakota/conf/version.properties

# Test S3 version path existence
aws s3 ls s3://bfc-tomcat-configs/prod/dakota/v7.8/ --profile bfc-tomcat-app-reader
aws s3 ls s3://bfc-tomcat-configs/prod/dakota/v7.9/ --profile bfc-tomcat-app-reader

# Run validation with version
./scripts/validate.sh -c gsf -p dakota -v -V dakota=7.9
./scripts/validate.sh -c tpc -p dakota -v -V dakota=7.8

# Test GitHub Actions workflow locally
# Use act or equivalent tool to test workflow with inputs:
# customer=tpc, products=dakota, versions=dakota=7.8
```

### **Workflow Changes Summary**:
- ✅ **Simplified to 5 input fields** for better GitHub UI display
- ✅ **Corrected version defaults**: Dakota 7.9, SelectPrime/API/Trax 1.0
- ✅ **Added TPC customer support** for Dakota 7.8 testing
- ✅ **Fixed version parsing logic** to handle combined version strings
- ✅ **Direct Ansible execution** for better error handling
- ✅ **Complete artifact upload support** including TPC
- ✅ **Maintained all functionality** while simplifying interface

This structure ensures consistency, scalability, and ease of maintenance across all products and customers, with comprehensive validation to ensure deployment-ready configurations for specific versions, including dedicated TPC support for Dakota 7.8 testing.