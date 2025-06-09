# 🚀 Quick Setup Instructions

## Step 1: Copy These Key Files First

Create these files in your `azure-vmss-monitoring` directory:

### Essential Files (Copy these first):
1. **README.md** - Project documentation 
2. **.gitignore** - Git ignore patterns
3. **terraform/main.tf** - Main Terraform configuration
4. **terraform/variables.tf** - Terraform variables
5. **terraform/environments/dev.tfvars.example** - Sample environment config
6. **scripts/deploy.sh** - Deployment script
7. **kql-queries/main-dashboard/vmss-rag-status.kql** - Main monitoring query

## Step 2: Create Directory Structure

```bash
mkdir -p azure-vmss-monitoring/{terraform/environments,scripts,kql-queries/main-dashboard,docs}
cd azure-vmss-monitoring
```

## Step 3: Copy File Contents

Copy each artifact content into the respective files:

```bash
# Copy README.md content from artifact 1
# Copy .gitignore content from artifact 2  
# Copy terraform/main.tf content from artifact 3
# Copy terraform/variables.tf content from artifact 4
# Copy terraform/environments/dev.tfvars.example content from artifact 5
# Copy scripts/deploy.sh content from artifact 6
# Copy kql-queries/main-dashboard/vmss-rag-status.kql content from artifact 7
```

## Step 4: Configure Your Environment

```bash
# 1. Copy the example environment file
cp terraform/environments/dev.tfvars.example terraform/environments/dev.tfvars

# 2. Edit with your actual values
vi terraform/environments/dev.tfvars

# Update these required values:
# - subscription_id (your Azure subscription ID)
# - tenant_id (your Azure tenant ID)  
# - vmss_resource_groups (your actual resource groups)
# - alert_email_addresses (your email for alerts)
```

## Step 5: Set Up Azure Permissions

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Create service principal (replace with your values)
az ad sp create-for-rbac \
  --name "sp-vmss-monitoring" \
  --role "Monitoring Reader" \
  --scopes "/subscriptions/your-subscription-id"

# Save the output - you'll need it for CI/CD
```

## Step 6: Deploy

```bash
# Make script executable
chmod +x scripts/deploy.sh

# Deploy to development
./scripts/deploy.sh -e dev

# Or just plan first
./scripts/deploy.sh -e dev -p
```

## Step 7: Verify

```bash
# Check resources were created
az resource list --resource-group "rg-vmss-monitoring-dev" --output table

# Check Log Analytics workspace
az monitor log-analytics workspace show \
  --resource-group "rg-vmss-monitoring-dev" \
  --workspace-name "law-vmss-monitoring-dev"
```

## 🎯 What You Get

After deployment:
- ✅ **Log Analytics Workspace** for collecting VMSS telemetry
- ✅ **Alert Rules** for critical CPU, memory, and instance issues
- ✅ **Action Groups** for email notifications
- ✅ **KQL Queries** for RAG status monitoring
- ✅ **RAG Dashboard** showing real-time VMSS health

## 🔧 Next Steps

1. **Add CI/CD** - Copy either GitHub Actions or GitLab CI/CD files
2. **Customize Thresholds** - Adjust monitoring thresholds in your .tfvars file
3. **Add More Environments** - Create staging.tfvars and prod.tfvars
4. **Set Up Workbooks** - Import Azure Workbook templates for dashboards
5. **Test Alerts** - Verify email notifications work

## 📊 Access Your Monitoring

- **Azure Portal**: Go to Monitor → Log Analytics → Your Workspace
- **Run KQL Query**: Copy the RAG status query and run it
- **View Results**: See your VMSS health in Red/Amber/Green format

## 🆘 Troubleshooting

- **No data**: Ensure Azure Monitor Agent is installed on VMSS instances
- **Permission errors**: Verify service principal has required roles
- **Terraform errors**: Check your .tfvars file has correct values

---

This gives you a **production-ready VMSS monitoring solution** in under 30 minutes! 🎉