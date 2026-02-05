# 🌐 Domain & Certificate Configuration Guide

## 🚨 **Current Issue Analysis**

### **Problem**: Subdomain Certificate Creation
You're trying to create ACM certificates for `dev.demo.powersmarter.net`, but the parent domain `demo.powersmarter.net` is managed in **another AWS account**.

### **Why ACM Validation Fails**
1. **DNS Validation**: Requires Route53 hosted zone ownership
2. **Cross-Account Domain**: Parent domain is in different AWS account
3. **Certificate Authority**: Can't validate domain ownership

## 🔧 **Solution Options**

### **Option 1: Use Existing Certificate (Recommended)**
If you already have a wildcard certificate for `*.demo.powersmarter.net`:

```hcl
# In terraform.tfvars
existing_certificate_arn = "arn:aws:acm:eu-west-2:ACCOUNT:certificate/CERT-ID"
existing_certificate_arn_us_east_1 = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT-ID"
```

### **Option 2: Cross-Account Certificate Sharing**
1. **Create certificate in parent account** (where `demo.powersmarter.net` is managed)
2. **Share certificate** via AWS Resource Access Manager (RAM)
3. **Use shared certificate ARN** in this account

### **Option 3: Subdomain Delegation**
1. **In parent account** (`demo.powersmarter.net`):
   ```bash
   # Create NS records for subdomain delegation
   aws route53 change-resource-record-sets --hosted-zone-id PARENT_ZONE_ID --change-batch '{
     "Changes": [{
       "Action": "CREATE",
       "ResourceRecordSet": {
         "Name": "dev.demo.powersmarter.net",
         "Type": "NS",
         "TTL": 300,
         "ResourceRecords": [
           {"Value": "ns1.dev.demo.powersmarter.net"},
           {"Value": "ns2.dev.demo.powersmarter.net"}
         ]
       }
     }]
   }'
   ```

2. **In this account**:
   - Create Route53 hosted zone for `dev.demo.powersmarter.net`
   - Update NS records in parent account to point to this zone
   - Then ACM validation will work

### **Option 4: Skip HTTPS (Development Only)**
For development/testing, use HTTP-only ALB:

```hcl
# In terraform.tfvars
skip_ssl_certificate = true
```

## 🛠️ **Implementation Steps**

### **Step 1: Choose Your Approach**
```bash
# Option 1: Use existing certificate
echo 'existing_certificate_arn = "arn:aws:acm:eu-west-2:794038252750:certificate/YOUR-CERT-ID"' >> terraform.tfvars

# Option 4: Skip SSL for now
echo 'skip_ssl_certificate = true' >> terraform.tfvars
```

### **Step 2: Clean Up Failed Resources**
```bash
# Delete scheduled-for-deletion secrets
aws secretsmanager delete-secret --secret-id rds-credentials-postgresql-instance --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id rds-connection-string-postgresql-instance --force-delete-without-recovery

# Import existing resources
chmod +x import_existing_resources.sh
./import_existing_resources.sh
```

### **Step 3: Deploy Infrastructure**
```bash
terraform plan
terraform apply
```

## 📋 **Required Variables for Certificate Management**

Add to your `terraform.tfvars`:

```hcl
# Domain configuration
smarterise_domain_root = "dev.demo.powersmarter.net"

# Certificate options (choose one)
existing_certificate_arn = "arn:aws:acm:eu-west-2:794038252750:certificate/YOUR-CERT-ID"  # Option 1
existing_certificate_arn_us_east_1 = "arn:aws:acm:us-east-1:794038252750:certificate/YOUR-CERT-ID"  # For CloudFront

# OR skip SSL entirely
skip_ssl_certificate = true  # Option 4
```

## 🔍 **Troubleshooting Commands**

### **Check Existing Certificates**
```bash
# List certificates in current region
aws acm list-certificates --region eu-west-2

# List certificates in us-east-1 (for CloudFront)
aws acm list-certificates --region us-east-1

# Check certificate details
aws acm describe-certificate --certificate-arn YOUR-CERT-ARN
```

### **Check Domain Ownership**
```bash
# Check Route53 hosted zones
aws route53 list-hosted-zones

# Check NS records for subdomain
dig NS dev.demo.powersmarter.net
```

### **Check Secrets Manager**
```bash
# List secrets scheduled for deletion
aws secretsmanager list-secrets --include-planned-deletion

# Force delete secrets
aws secretsmanager delete-secret --secret-id SECRET-NAME --force-delete-without-recovery
```

## 🎯 **Recommended Immediate Action**

For **quick deployment**, use Option 4 (skip SSL):

```bash
# 1. Add to terraform.tfvars
echo 'skip_ssl_certificate = true' >> terraform.tfvars

# 2. Clean up conflicts
aws secretsmanager delete-secret --secret-id rds-credentials-postgresql-instance --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id rds-connection-string-postgresql-instance --force-delete-without-recovery

# 3. Import existing resources
./import_existing_resources.sh

# 4. Deploy
terraform apply
```

This will get your infrastructure running immediately. You can add SSL certificates later once domain delegation is properly configured.

## 🔐 **Security Considerations**

- **Development**: HTTP-only is acceptable for dev environments
- **Production**: Always use HTTPS with valid certificates
- **Certificate Management**: Use AWS Certificate Manager for automatic renewal
- **Cross-Account**: Implement proper IAM policies for certificate sharing

Your infrastructure will be fully functional without SSL, and you can add certificates later when domain ownership is resolved! 🚀