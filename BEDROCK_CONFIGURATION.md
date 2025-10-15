# AWS Bedrock Configuration Guide

This guide documents the complete configuration requirements for AWS Bedrock with the Nova Pro model, including critical learnings from production deployment.

## Overview

The ProductsAgent uses AWS Bedrock for AI-powered responses. This guide covers:
- Model access requirements
- Inference profile configuration
- Multi-region IAM permissions
- Common deployment issues and solutions

## Nova Pro Model Configuration

### Critical Requirements

**⚠️ Important**: Nova Pro requires **inference profiles**, not direct model access.

#### 1. Model Access Enablement

Enable Nova Pro model access in the AWS Console:

1. Navigate to AWS Bedrock console in **eu-central-1** region
2. Go to "Model Access" in the left sidebar
3. Request access to the **Nova Pro** model
4. Wait for approval (this may take some time)

#### 2. Inference Profile Configuration

**Correct Configuration**:
```bash
export BEDROCK_MODEL_ID="eu.amazon.nova-pro-v1:0"  # Inference profile ID
export BEDROCK_REGION="eu-central-1"
export BEDROCK_TEMPERATURE="0.1"
```

**Incorrect Configuration**:
```bash
export BEDROCK_MODEL_ID="amazon.nova-pro-v1:0"  # Direct model ID - will fail
```

#### 3. Error Messages and Solutions

**Error**: `ValidationException: Invocation of model ID amazon.nova-pro-v1:0 with on-demand throughput isn't supported`

**Solution**: Use inference profile ID instead:
```bash
# Change from:
BEDROCK_MODEL_ID="amazon.nova-pro-v1:0"

# To:
BEDROCK_MODEL_ID="eu.amazon.nova-pro-v1:0"
```

**Error**: `AccessDeniedException: User is not authorized to perform: bedrock:InvokeModel`

**Solution**: Ensure IAM policy includes inference profile ARNs for all supported regions.

## Multi-Region IAM Policy Requirements

### Supported Regions

Nova Pro inference profiles are available in multiple regions:
- `eu-central-1` (primary)
- `eu-west-3`
- `eu-west-1`
- `eu-north-1`

### IAM Policy Configuration

The Terraform configuration automatically includes all required permissions:

```hcl
# terraform/modules/bastion/alb-resources.tf
data "aws_iam_policy_document" "bedrock_policy" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModels"
    ]
    resources = [
      # Inference profiles for all supported regions
      "arn:aws:bedrock:eu-central-1:YOUR_AWS_ACCOUNT_ID:inference-profile/eu.amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-west-3:YOUR_AWS_ACCOUNT_ID:inference-profile/eu.amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-west-1:YOUR_AWS_ACCOUNT_ID:inference-profile/eu.amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-north-1:YOUR_AWS_ACCOUNT_ID:inference-profile/eu.amazon.nova-pro-v1:0",
      
      # Foundation models for all supported regions
      "arn:aws:bedrock:eu-central-1::foundation-model/amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-west-3::foundation-model/amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-west-1::foundation-model/amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-north-1::foundation-model/amazon.nova-pro-v1:0",
      
      # Additional Nova models
      "arn:aws:bedrock:eu-central-1::foundation-model/amazon.nova-lite-v1:0",
      "arn:aws:bedrock:eu-central-1::foundation-model/amazon.nova-micro-v1:0",
      
      # Claude models for fallback
      "arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0",
      "arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
      "arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
    ]
  }
}
```

### Account ID Configuration

**Important**: The IAM policy includes the specific AWS account ID (`YOUR_AWS_ACCOUNT_ID`). This must be updated for different AWS accounts:

```hcl
# Update this account ID in terraform/modules/bastion/alb-resources.tf
resources = [
  "arn:aws:bedrock:eu-central-1:YOUR_ACCOUNT_ID:inference-profile/eu.amazon.nova-pro-v1:0",
  # ... other ARNs
]
```

## Environment Variable Configuration

### Docker Compose Configuration

```yaml
# docker-compose/products-agent/docker-compose.yml
services:
  products-agent:
    environment:
      - BEDROCK_MODEL_ID=${BEDROCK_MODEL_ID:-eu.amazon.nova-pro-v1:0}
      - BEDROCK_TEMPERATURE=${BEDROCK_TEMPERATURE:-0.1}
      - BEDROCK_REGION=${BEDROCK_REGION:-eu-central-1}
      - USE_MOCK_MODEL=false
```

### Export Script Configuration

```bash
# terraform/export-env.sh
# Bedrock LLM configuration
BEDROCK_MODEL_ID=${BEDROCK_MODEL_ID:-anthropic.claude-3-5-sonnet-20240620-v1:0}
BEDROCK_TEMPERATURE=${BEDROCK_TEMPERATURE:-0.1}
BEDROCK_REGION=${BEDROCK_REGION:-eu-central-1}
```

### Deployment Script Configuration

```bash
# deploy-ecr.sh
export BEDROCK_MODEL_ID=${BEDROCK_MODEL_ID:-anthropic.claude-3-5-sonnet-20240620-v1:0}
export BEDROCK_TEMPERATURE=${BEDROCK_TEMPERATURE:-0.1}
export BEDROCK_REGION=${BEDROCK_REGION:-eu-central-1}
```

## Alternative Model Configurations

### Claude Models (Fallback)

If Nova Pro is not available, you can use Claude models:

```bash
# Claude 3.5 Sonnet
export BEDROCK_MODEL_ID="anthropic.claude-3-5-sonnet-20240620-v1:0"

# Claude 3 Sonnet
export BEDROCK_MODEL_ID="anthropic.claude-3-sonnet-20240229-v1:0"

# Claude 3 Haiku
export BEDROCK_MODEL_ID="anthropic.claude-3-haiku-20240307-v1:0"
```

### Mock Model (Development)

For development without AWS Bedrock access:

```bash
export USE_MOCK_MODEL=true
```

## Deployment Commands

### Quick Configuration

```bash
# Set Nova Pro configuration
export BEDROCK_MODEL_ID="eu.amazon.nova-pro-v1:0"
export BEDROCK_TEMPERATURE="0.1"
export BEDROCK_REGION="eu-central-1"

# Deploy with custom configuration
./deploy-ecr.sh full
```

### Step-by-Step Deployment

```bash
# 1. Configure Bedrock
export BEDROCK_MODEL_ID="eu.amazon.nova-pro-v1:0"
export BEDROCK_REGION="eu-central-1"

# 2. Login to ECR
./deploy-ecr.sh login

# 3. Build and push images
./deploy-ecr.sh build

# 4. Deploy to AWS
./deploy-ecr.sh deploy
```

## Troubleshooting

### Common Issues

#### 1. Model Access Denied

**Error**: `AccessDeniedException: You don't have access to the model with the specified model ID`

**Solutions**:
1. Enable model access in AWS Bedrock console
2. Wait for approval (can take time)
3. Check IAM permissions include correct ARNs
4. Verify account ID in IAM policy

#### 2. Inference Profile Not Found

**Error**: `ValidationException: Invocation of model ID amazon.nova-pro-v1:0 with on-demand throughput isn't supported`

**Solution**: Use inference profile ID:
```bash
# Wrong
BEDROCK_MODEL_ID="amazon.nova-pro-v1:0"

# Correct
BEDROCK_MODEL_ID="eu.amazon.nova-pro-v1:0"
```

#### 3. Region Mismatch

**Error**: `AccessDeniedException: User is not authorized to perform: bedrock:InvokeModel`

**Solution**: Ensure IAM policy includes all supported regions:
- `eu-central-1`
- `eu-west-3`
- `eu-west-1`
- `eu-north-1`

#### 4. Account ID Mismatch

**Error**: IAM policy references wrong account ID

**Solution**: Update account ID in Terraform:
```bash
# Get your account ID
aws sts get-caller-identity --query Account --output text

# Update terraform/modules/bastion/alb-resources.tf
# Replace YOUR_AWS_ACCOUNT_ID with your account ID
```

### Debug Commands

```bash
# Check Bedrock model access
aws bedrock list-foundation-models --region eu-central-1

# Check inference profiles
aws bedrock list-inference-profiles --region eu-central-1

# Test model invocation
aws bedrock invoke-model \
  --model-id eu.amazon.nova-pro-v1:0 \
  --body '{"prompt": "Hello"}' \
  --region eu-central-1

# Check IAM permissions
aws iam get-role-policy \
  --role-name ai-l0q-bastion-role \
  --policy-name ai-l0q-bedrock-access
```

## Best Practices

### 1. Use Inference Profiles

Always use inference profile IDs for Nova Pro:
```bash
# Good
BEDROCK_MODEL_ID="eu.amazon.nova-pro-v1:0"

# Bad
BEDROCK_MODEL_ID="amazon.nova-pro-v1:0"
```

### 2. Multi-Region Support

Include all supported regions in IAM policy:
```hcl
resources = [
  "arn:aws:bedrock:eu-central-1:ACCOUNT:inference-profile/eu.amazon.nova-pro-v1:0",
  "arn:aws:bedrock:eu-west-3:ACCOUNT:inference-profile/eu.amazon.nova-pro-v1:0",
  "arn:aws:bedrock:eu-west-1:ACCOUNT:inference-profile/eu.amazon.nova-pro-v1:0",
  "arn:aws:bedrock:eu-north-1:ACCOUNT:inference-profile/eu.amazon.nova-pro-v1:0"
]
```

### 3. Environment Variable Precedence

Use environment variables for configuration:
```bash
# Override defaults
export BEDROCK_MODEL_ID="eu.amazon.nova-pro-v1:0"
export BEDROCK_REGION="eu-central-1"
```

### 4. Fallback Configuration

Always have fallback models configured:
```bash
# Primary: Nova Pro
BEDROCK_MODEL_ID="eu.amazon.nova-pro-v1:0"

# Fallback: Claude
BEDROCK_MODEL_ID="anthropic.claude-3-5-sonnet-20240620-v1:0"

# Development: Mock
USE_MOCK_MODEL=true
```

## Cost Considerations

### Nova Pro Pricing

- **Inference Profiles**: Higher throughput, lower latency
- **On-Demand**: Pay per request
- **Provisioned**: Reserved capacity

### Cost Optimization

1. **Use appropriate model size**:
   - `nova-micro-v1:0` - Smallest, cheapest
   - `nova-lite-v1:0` - Balanced
   - `nova-pro-v1:0` - Most capable, most expensive

2. **Monitor usage**:
   ```bash
   # Check Bedrock usage
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Bedrock \
     --metric-name InvokeModelCount \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-02T00:00:00Z \
     --period 3600 \
     --statistics Sum
   ```

3. **Set up billing alerts**:
   - Configure CloudWatch alarms
   - Set up AWS Budgets
   - Monitor cost anomalies

## Security Considerations

### 1. IAM Least Privilege

Only grant necessary Bedrock permissions:
```hcl
actions = [
  "bedrock:InvokeModel",
  "bedrock:InvokeModelWithResponseStream",
  "bedrock:ListFoundationModels"
]
```

### 2. Resource-Level Permissions

Use specific ARNs instead of wildcards:
```hcl
# Good - specific ARNs
resources = [
  "arn:aws:bedrock:eu-central-1:ACCOUNT:inference-profile/eu.amazon.nova-pro-v1:0"
]

# Bad - wildcard
resources = ["*"]
```

### 3. Network Security

- Use VPC endpoints for Bedrock access
- Restrict outbound internet access
- Monitor Bedrock API calls

## Monitoring and Logging

### CloudWatch Metrics

Monitor key metrics:
- `InvokeModelCount` - Number of model invocations
- `InvokeModelLatency` - Response time
- `InvokeModelErrors` - Error rate

### Logging Configuration

Enable detailed logging:
```bash
# Set log level
export LOG_LEVEL=INFO

# Enable Bedrock logging
export BEDROCK_LOG_LEVEL=DEBUG
```

### Alerting

Set up alerts for:
- High error rates
- Unusual latency
- Cost anomalies
- Model access issues

---

**⚠️ Important**: This configuration has been tested in production with Nova Pro in the eu-central-1 region. Ensure all hardcoded values (account IDs, regions, etc.) are updated for your specific deployment.