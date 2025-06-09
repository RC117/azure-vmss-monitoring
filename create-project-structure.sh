#!/bin/bash
# =========================================================
# Script to create the basic Azure VMSS Monitoring project structure
# Run this in your azure-vmss-monitoring directory
# =========================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status "Creating Azure VMSS Monitoring project structure..."

# Create directory structure
print_status "Creating directories..."
mkdir -p terraform/{modules/{log-analytics,alerts,workbooks},environments}
mkdir -p kql-queries/{main-dashboard,supporting-queries,alert-queries}
mkdir -p workbooks
mkdir -p scripts
mkdir -p docs
mkdir -p .github/workflows
mkdir -p .gitlab/{merge_request_templates,issue_templates}

print_success "Directory structure created!"

# Create basic terraform/main.tf
print_status "Creating basic Terraform files..."

cat > terraform/main.tf << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "monitoring" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    Environment = var.environment
    Purpose     = "VMSS Monitoring"
    ManagedBy   = "Terraform"
  }
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = var.workspace_name
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                = "PerGB2018"
  retention_in_days   = var.retention_days

  tags = {
    Environment = var.environment
    Purpose     = "VMSS Monitoring"
    ManagedBy   = "Terraform"
  }
}

output "resource_group_name" {
  description = "Name of the monitoring resource group"
  value       = azurerm_resource_group.monitoring.name
}

output "workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}
EOF

# Create terraform/variables.tf
cat > terraform/variables.tf << 'EOF'
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group for monitoring infrastructure"
  type        = string
}

variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 90
}

variable "vmss_resource_groups" {
  description = "List of resource groups containing VMSS to monitor"
  type        = list(string)
  default     = []
}
EOF

# Create terraform/environments/dev.tfvars.template
cat > terraform/environments/dev.tfvars.template << 'EOF'
# Azure Configuration - REPLACE WITH YOUR VALUES
subscription_id = "12345678-1234-1234-1234-123456789abc"  # Your subscription ID
tenant_id      = "87654321-4321-4321-4321-cba987654321"  # Your tenant ID
location       = "East US"                               # Your preferred region

# Project Configuration
environment         = "dev"
resource_group_name = "rg-vmss-monitoring-dev"
workspace_name     = "law-vmss-monitoring-dev"
retention_days     = 30

# VMSS Configuration - ADD YOUR VMSS RESOURCE GROUPS
vmss_resource_groups = [
  "rg-web-dev",
  "rg-api-dev"
  # Add your actual resource group names here
]
EOF

# Create basic KQL query
cat > kql-queries/main-dashboard/basic-vmss-health.kql << 'EOF'
// Basic VMSS Health Check Query
// This is a starter query - more comprehensive queries will be added later

Heartbeat
| where TimeGenerated > ago(10m)
| where Computer startswith "vmss"
| summarize LastSeen = max(TimeGenerated) by Computer
| extend MinutesAgo = datetime_diff('minute', now(), LastSeen)
| extend Status = case(
    MinutesAgo <= 2, "🟢 Healthy",
    MinutesAgo <= 5, "🟡 Warning", 
    "🔴 Critical"
)
| join kind=leftouter (
    VMComputer
    | where TimeGenerated > ago(1h)
    | extend VMSSName = case(
        AzureResourceName contains "_", tostring(split(AzureResourceName, "_")[0]),
        AzureResourceName
    )
    | distinct Computer, VMSSName, ResourceGroupName=AzureResourceGroup
) on Computer
| where isnotempty(VMSSName)
| summarize 
    TotalInstances = count(),
    HealthyCount = countif(Status contains "🟢"),
    WarningCount = countif(Status contains "🟡"),
    CriticalCount = countif(Status contains "🔴")
    by VMSSName, ResourceGroupName
| extend OverallStatus = case(
    CriticalCount > 0, "🔴 CRITICAL",
    WarningCount > 0, "🟡 WARNING",
    "🟢 HEALTHY"
)
| project VMSSName, ResourceGroupName, OverallStatus, TotalInstances, HealthyCount, WarningCount, CriticalCount
| sort by OverallStatus asc, VMSSName asc
EOF

# Create validation script
cat > scripts/validate-setup.sh << 'EOF'
#!/bin/bash
# Quick validation script

echo "🔍 Validating Azure VMSS Monitoring setup..."

# Check if we're in the right directory
if [[ ! -f "terraform/main.tf" ]]; then
    echo "❌ terraform/main.tf not found. Are you in the project root?"
    exit 1
fi

# Check if required tools are installed
echo "Checking required tools..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not installed"
    echo "Install from: https://developer.hashicorp.com/terraform/downloads"
    exit 1
else
    echo "✅ Terraform found: $(terraform version -json | jq -r '.terraform_version')"
fi

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not installed"
    echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
else
    echo "✅ Azure CLI found: $(az version --query '"azure-cli"' -o tsv)"
fi

# Check Azure login
if ! az account show &> /dev/null; then
    echo "❌ Not logged in to Azure CLI"
    echo "Run: az login"
    exit 1
else
    echo "✅ Azure CLI logged in: $(az account show --query name -o tsv)"
fi

# Check if environment file exists
if [[ ! -f "terraform/environments/dev.tfvars" ]]; then
    echo "⚠️  Dev environment file not found"
    echo "Copy and edit: cp terraform/environments/dev.tfvars.template terraform/environments/dev.tfvars"
else
    echo "✅ Dev environment file exists"
fi

echo ""
echo "🎉 Setup validation complete!"
echo ""
echo "Next steps:"
echo "1. Edit terraform/environments/dev.tfvars with your Azure details"
echo "2. Run: ./scripts/deploy.sh -e dev -p (to plan)"
echo "3. Run: ./scripts/deploy.sh -e dev (to deploy)"
EOF

chmod +x scripts/validate-setup.sh

print_success "Basic Terraform files created!"

# Create basic docs
print_status "Creating documentation..."

cat > docs/quick-start.md << 'EOF'
# Quick Start Guide

## 1. Prerequisites
- Azure CLI installed and logged in
- Terraform >= 1.0 installed
- Azure subscription with appropriate permissions

## 2. Setup
1. Edit `terraform/environments/dev.tfvars` with your Azure details
2. Run `./scripts/validate-setup.sh` to check prerequisites
3. Run `./scripts/deploy.sh -e dev -p` to plan deployment
4. Run `./scripts/deploy.sh -e dev` to deploy

## 3. Validation
- Check Azure portal for the created resource group
- Verify Log Analytics workspace is created
- Test the basic KQL query in Log Analytics

## 4. Next Steps
- Add more comprehensive monitoring queries
- Set up alerts and dashboards
- Configure CI/CD pipeline
EOF

print_success "Documentation created!"

# Create .gitignore if it doesn't exist
if [[ ! -f ".gitignore" ]]; then
cat > .gitignore << 'EOF'
# Terraform
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfvars.backup
*.tfplan
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

# Azure CLI
.azure/

# Local environment files
.env
.env.local
.env.*.local

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Temporary files
*.tmp
*.temp
EOF
print_success ".gitignore created!"
fi

echo ""
print_success "Project structure created successfully!"
echo ""
print_warning "IMPORTANT NEXT STEPS:"
echo "1. Copy terraform/environments/dev.tfvars.template to terraform/environments/dev.tfvars"
echo "2. Edit dev.tfvars with your actual Azure subscription ID and tenant ID"
echo "3. Run: ./scripts/validate-setup.sh"
echo "4. Run: ./scripts/deploy.sh -e dev -p (to test)"
echo ""
print_status "Your project is ready for basic deployment! 🚀"