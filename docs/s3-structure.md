# S3 Storage Structure for BFC Tomcat Configuration Files

This document outlines the S3 bucket structure used for storing Tomcat configuration files for both i Series and AWS deployments.

## Bucket Layout

```
bfc-tomcat-configs/
├── environment/                      # prod, test, dev
│   ├── prod/
│   │   ├── iseries/                  # For i Series deployment
│   │   │   ├── products/
│   │   │   │   ├── dakota/
│   │   │   │   │   ├── GSF/
│   │   │   │   │   │   ├── conf/
│   │   │   │   │   │   │   ├── server.xml
│   │   │   │   │   │   │   └── ...
│   │   │   │   │   └── ...
│   │   │   │   ├── selectprime/
│   │   │   │   ├── api/
│   │   │   │   └── trax/
│   │   │   └── bundles/              # Complete deployment packages
│   │   │       ├── GSF/
│   │   │       │   ├── gsf-dakota-configs.zip
│   │   │       │   └── ...
│   │   │       └── ...
│   │   └── aws/                      # For AWS deployment (future use)
│   │       ├── products/             # Same structure as iseries
│   │       └── bundles/              # Complete deployment packages
│   ├── test/
│   └── dev/
└── history/                          # Optional: Versioned configurations (managed by S3 versioning)
```

## IAM Structure

The project uses the following IAM structure for S3 access:

| **Group**                          | **Policy**                     | **User**                      |
|-----------------------------------|--------------------------------|-------------------------------|
| `bfc-tomcat-deploy-group`         | `bfc-tomcat-s3-access`         | `bfc-tomcat-github-actions`   |
| `bfc-tomcat-github-actions-group` | `bfc-tomcat-s3-upload-only`    | `bfc-tomcat-github-uploader`  |
| `bfc-tomcat-application-group`    | `bfc-tomcat-s3-download-only`  | `bfc-tomcat-app-reader`       |

## Accessing Configuration Files

### Using the CLI tools

1. To fetch individual configuration files:
   ```bash
   ./scripts/fetch-config.sh -c GSF -p dakota -e prod -t iseries -P bfc-tomcat-app-reader
   ```

2. To upload generated configurations:
   ```bash
   ./scripts/upload-to-s3.sh -c gsf -p dakota -e prod -t iseries -P bfc-tomcat-github-uploader
   ```

### Using AWS CLI directly

1. Download configuration files:
   ```bash
   aws s3 cp s3://bfc-tomcat-configs/environment/prod/iseries/products/dakota/GSF/ ./downloaded-configs/ \
       --recursive --profile bfc-tomcat-app-reader
   ```

2. Upload configuration files:
   ```bash
   aws s3 cp output/dakota/GSF/ s3://bfc-tomcat-configs/environment/prod/iseries/products/dakota/GSF/ \
       --recursive --profile bfc-tomcat-github-uploader
   ```

3. List available configurations:
   ```bash
   aws s3 ls s3://bfc-tomcat-configs/environment/prod/iseries/products/ --profile bfc-tomcat-app-reader
   ```

## Directory Structure Creation

Initial S3 directory structure was created with the following commands:

```bash
# Create environment directories
aws s3api put-object --bucket bfc-tomcat-configs --key environment/prod/ --profile bfc-tomcat-github-uploader
aws s3api put-object --bucket bfc-tomcat-configs --key environment/test/ --profile bfc-tomcat-github-uploader
aws s3api put-object --bucket bfc-tomcat-configs --key environment/dev/ --profile bfc-tomcat-github-uploader

# Create deployment target directories
aws s3api put-object --bucket bfc-tomcat-configs --key environment/prod/iseries/ --profile bfc-tomcat-github-uploader
aws s3api put-object --bucket bfc-tomcat-configs --key environment/prod/aws/ --profile bfc-tomcat-github-uploader

# Create product directories
aws s3api put-object --bucket bfc-tomcat-configs --key environment/prod/iseries/products/ --profile bfc-tomcat-github-uploader
aws s3api put-object --bucket bfc-tomcat-configs --key environment/prod/iseries/bundles/ --profile bfc-tomcat-github-uploader
```

## Versioning and History

The `history/` directory is an optional feature enabled by S3 versioning. To enable versioning:

```bash
aws s3api put-bucket-versioning --bucket bfc-tomcat-configs --versioning-configuration Status=Enabled --profile bfc-tomcat-admin
```

When versioning is enabled, previous versions of configuration files can be accessed through the AWS console or CLI.

## Security Considerations

- Production and sensitive configurations are protected by IAM policies
- Application access is limited to read-only permissions via the `bfc-tomcat-app-reader` user
- Deployment and upload permissions are restricted to CI/CD systems
- Credentials should never be stored in config files or source code

## Future Enhancements

- Implement CloudWatch alerts for configuration changes
- Add CloudTrail logging for all S3 access
- Consider implementing S3 Event Notifications to trigger deployments
- Add lifecycle policies to manage versions and optimize storage costs
