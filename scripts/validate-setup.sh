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
