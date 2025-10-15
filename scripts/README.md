# 🔧 Automated Secret Management Scripts

This directory contains automated scripts that handle Azure AD client secret updates that occur during Terraform applies, eliminating the need for manual intervention.

## 🎯 Problem Solved

**Issue**: After running `terraform apply`, Azure AD application passwords are regenerated, but Docker containers continue using the old client secrets, causing authentication failures.

**Solution**: Automated scripts that detect secret mismatches and update containers automatically.

## 📁 Scripts Overview

### 1. `config.sh` - Configuration File
- **Purpose**: Centralized configuration for all scripts
- **Action**: Contains all hardcoded values as variables
- **Usage**: Automatically loaded by other scripts

### 2. `auto-configure.sh` - Auto-Configuration Script
- **Purpose**: Automatically populates config.sh with Terraform outputs
- **Action**: Reads Terraform outputs and updates configuration
- **Usage**: Run after `terraform apply` to update configuration

### 3. `update-secrets.sh` - Main Update Script
- **Purpose**: Compares Terraform outputs with container environment variables
- **Action**: Updates both `.env` files and `docker-compose.yml` hardcoded values, then recreates containers
- **Usage**: Run manually or automatically after Terraform applies

### 4. `check-auth-health.sh` - Health Monitor
- **Purpose**: Monitors authentication health and triggers updates when issues detected
- **Action**: Checks logs for authentication failures and HTTP health endpoints
- **Usage**: Run periodically or manually to check system health

### 5. `terraform-post-apply.sh` - Terraform Hook
- **Purpose**: Automatically runs after `terraform apply`
- **Action**: Triggers secret update process
- **Usage**: Integrate with Terraform workflow

### 6. `update-docker-compose-variables.sh` - Docker Compose Variable Updater
- **Purpose**: Replaces hardcoded values in docker-compose files with environment variables
- **Action**: Updates docker-compose.yml files to use variables instead of hardcoded values
- **Usage**: Run once to convert hardcoded values to variables

## 🚀 Quick Start

### Initial Setup (One-time)
```bash
# 1. Auto-configure scripts with Terraform outputs
./scripts/auto-configure.sh

# 2. Update docker-compose files to use variables (optional)
./scripts/update-docker-compose-variables.sh
```

### Manual Update (Immediate Fix)
```bash
# Fix current authentication issues
./scripts/update-secrets.sh
```

### Health Check
```bash
# Check system health and fix issues if found
./scripts/check-auth-health.sh
```

### Terraform Integration
```bash
# Run after terraform apply
./scripts/terraform-post-apply.sh
```

## ⚙️ Configuration Management

### Automatic Configuration
The scripts now use a centralized configuration file (`config.sh`) that is automatically populated from Terraform outputs:

```bash
# Auto-configure after terraform apply
terraform apply
./scripts/auto-configure.sh
```

### Manual Configuration
If you need to manually update configuration values, edit `scripts/config.sh`:

```bash
# Edit configuration file
nano scripts/config.sh

# Key variables to update:
# - BASTION_HOST: Your bastion host IP
# - TENANT_ID: Your Microsoft Entra ID tenant ID
# - PRODUCTS_AGENT_CLIENT_ID: ProductsAgent app registration ID
# - PRODUCTS_WEB_CLIENT_ID: ProductsWeb app registration ID
# - PRODUCTS_MCP_CLIENT_ID: ProductsMCP app registration ID
```

### Docker Compose Variables
Convert hardcoded values in docker-compose files to environment variables:

```bash
# Update docker-compose files to use variables
./scripts/update-docker-compose-variables.sh
```

This replaces hardcoded values like:
- `ENTRA_CLIENT_ID=${PRODUCTS_AGENT_CLIENT_ID}` → `ENTRA_CLIENT_ID=${ENTRA_CLIENT_ID}`
- `https://login.microsoftonline.com/${TENANT_ID}` → `https://login.microsoftonline.com/${TENANT_ID}`

## 🔄 Automated Workflow Options

### Option 1: Manual Monitoring
Run health checks periodically:
```bash
# Check every 5 minutes
while true; do
    ./scripts/check-auth-health.sh
    sleep 300
done
```

### Option 2: Cron Job
Add to crontab for automatic monitoring:
```bash
# Check every 5 minutes
*/5 * * * * /path/to/confused-deputy-aws/scripts/check-auth-health.sh
```

### Option 3: Terraform Hook
Integrate with Terraform workflow:
```bash
# After every terraform apply
terraform apply && ./scripts/terraform-post-apply.sh
```

## 📊 What the Scripts Do

### Secret Update Process
1. **Compare Secrets**: Terraform output vs container environment
2. **Detect Mismatches**: Identify outdated client secrets
3. **Update Files**: Modify both `.env` files and `docker-compose.yml` hardcoded values
4. **Recreate Containers**: Complete container recreation (not just restart)
5. **Verify Health**: Confirm services are running and healthy

### Health Monitoring
1. **Log Analysis**: Check recent logs for authentication errors
2. **HTTP Health**: Verify service endpoints are responding
3. **Auto-Fix**: Trigger secret updates when issues detected
4. **Reporting**: Provide clear status messages

## 🎯 Services Monitored

- **ProductsAgent** (`${PRODUCTS_AGENT_CLIENT_ID}`)
  - Environment: `ENTRA_CLIENT_SECRET`
  - Health: `http://localhost:8001/health`
  - Log Pattern: `invalid_client|AADSTS7000215|Token exchange failed`

- **ProductsWeb** (`${PRODUCTS_WEB_CLIENT_ID}`)
  - Environment: `CLIENT_SECRET`
  - Health: `http://localhost:8501/_stcore/health`
  - Log Pattern: `invalid_client|AADSTS7000215|Authentication failed`

## 🔍 Troubleshooting

### Check Script Status
```bash
# Verify scripts are executable
ls -la scripts/*.sh

# Test individual components
./scripts/update-secrets.sh
./scripts/check-auth-health.sh
```

### Manual Verification
```bash
# Check container secrets
ssh -i "$SSH_KEY" ubuntu@"$BASTION_HOST" \
    "docker exec products-agent env | grep ENTRA_CLIENT_SECRET"

# Check Terraform outputs
terraform output products_agent_client_secret
```

### Log Analysis
```bash
# Check recent authentication errors
ssh -i "$SSH_KEY" ubuntu@"$BASTION_HOST" \
    "docker logs products-agent --since=5m | grep -i 'invalid_client\|AADSTS7000215'"
```

## ✅ Benefits

1. **Zero Manual Intervention**: No more manual secret updates
2. **Proactive Monitoring**: Detects issues before they impact users
3. **Automatic Recovery**: Self-healing system that fixes issues automatically
4. **Clear Reporting**: Detailed logs of what was updated and why
5. **Terraform Integration**: Seamless workflow integration
6. **Production Ready**: Handles all edge cases and provides verification

## 🎉 Result

**Before**: Manual intervention required every time Terraform regenerates secrets
**After**: Fully automated system that handles secret updates transparently

The recurring authentication issues are now completely solved! 🚀