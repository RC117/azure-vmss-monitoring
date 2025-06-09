#!/bin/bash
# =========================================================
# SIMPLE DEPLOYMENT SCRIPT FOR VMSS MONITORING
# =========================================================

set -euo pipefail

# Default values
ENVIRONMENT="dev"
AUTO_APPROVE="false"
PLAN_ONLY="false"
DESTROY="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy VMSS monitoring infrastructure using Terraform

OPTIONS:
    -e, --environment ENVIRONMENT    Environment to deploy (dev, staging, prod) [default: dev]
    -a, --auto-approve              Auto-approve terraform apply (dangerous!)
    -p, --plan-only                 Only run terraform plan, don't apply
    -d, --destroy                   Destroy infrastructure instead of creating
    -h, --help                      Show this help message

EXAMPLES:
    $0 -e prod                      Deploy to production (with confirmation)
    $0 -e staging -a                Deploy to staging with auto-approval
    $0 -e prod -p                   Plan production deployment without applying
    $0 -e dev -d                    Destroy development environment

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--auto-approve)
            AUTO_APPROVE="true"
            shift
            ;;
        -p|--plan-only)
            PLAN_ONLY="true"
            shift
            ;;
        -d|--destroy)
            DESTROY="true"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
    exit 1
fi

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v az &> /dev/null; then
        missing_tools+=("azure-cli")
    fi
    
    if [[ ${#missing_tools[@]} -ne 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check Terraform version
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    print_status "Using Terraform version: $tf_version"
    
    # Check Azure CLI login
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    local account_name=$(az account show --query name -o tsv)
    print_status "Using Azure account: $account_name"
}

# Validate Terraform configuration
validate_terraform() {
    print_status "Validating Terraform configuration..."
    
    cd terraform
    
    if ! terraform validate; then
        print_error "Terraform configuration validation failed!"
        exit 1
    fi
    
    print_success "Terraform configuration is valid"
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    cd terraform
    
    # Initialize with backend configuration if it exists
    if [[ -f "backend-${ENVIRONMENT}.conf" ]]; then
        terraform init -backend-config="backend-${ENVIRONMENT}.conf"
    else
        terraform init
    fi
    
    print_success "Terraform initialized successfully"
}

# Plan Terraform deployment
plan_terraform() {
    print_status "Planning Terraform deployment for $ENVIRONMENT..."
    
    cd terraform
    
    local tfvars_file="environments/${ENVIRONMENT}.tfvars"
    
    if [[ ! -f "$tfvars_file" ]]; then
        print_error "Environment file not found: $tfvars_file"
        print_error "Please create the file or copy from the template:"
        print_error "cp environments/dev.tfvars.example $tfvars_file"
        exit 1
    fi
    
    local plan_args=("-var-file=$tfvars_file" "-out=tfplan-${ENVIRONMENT}")
    
    if [[ "$DESTROY" == "true" ]]; then
        plan_args+=("-destroy")
    fi
    
    if terraform plan "${plan_args[@]}"; then
        print_success "Terraform plan completed successfully"
        return 0
    else
        print_error "Terraform plan failed!"
        return 1
    fi
}

# Apply Terraform deployment
apply_terraform() {
    print_status "Applying Terraform deployment for $ENVIRONMENT..."
    
    cd terraform
    
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        print_warning "Auto-approval enabled - applying without confirmation!"
    else
        echo
        if [[ "$DESTROY" == "true" ]]; then
            print_warning "⚠️  WARNING: This will DESTROY infrastructure in $ENVIRONMENT environment!"
            print_warning "This action cannot be undone!"
        else
            print_warning "This will deploy infrastructure to $ENVIRONMENT environment."
        fi
        read -p "Are you sure you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            print_status "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    if terraform apply "tfplan-${ENVIRONMENT}"; then
        if [[ "$DESTROY" == "true" ]]; then
            print_success "Infrastructure destroyed successfully!"
        else
            print_success "Terraform deployment completed successfully!"
            
            # Show outputs
            print_status "Deployment outputs:"
            terraform output
        fi
        return 0
    else
        print_error "Terraform operation failed!"
        return 1
    fi
}

# Create sample environment file if it doesn't exist
create_sample_env_file() {
    local env_file="terraform/environments/${ENVIRONMENT}.tfvars"
    
    if [[ ! -f "$env_file" ]]; then
        print_warning "Environment file not found: $env_file"
        print_status "Creating sample environment file..."
        
        cat > "$env_file" << EOF
# Azure Configuration - UPDATE THESE VALUES
subscription_id = "12345678-1234-1234-1234-123456789abc"  # Replace with your subscription ID
tenant_id       = "87654321-4321-4321-4321-cba987654321"  # Replace with your tenant ID
location        = "East US"

# Project Configuration
environment         = "$ENVIRONMENT"
resource_group_name = "rg-vmss-monitoring-$ENVIRONMENT"
workspace_name      = "law-vmss-monitoring-$ENVIRONMENT"
retention_days      = $([ "$ENVIRONMENT" = "prod" ] && echo "90" || echo "30")

# VMSS Configuration - UPDATE THESE VALUES
vmss_resource_groups = [
  "rg-web-$ENVIRONMENT",
  "rg-api-$ENVIRONMENT"
]

# Monitoring Thresholds
cpu_critical_threshold = $([ "$ENVIRONMENT" = "prod" ] && echo "85" || echo "95")
cpu_warning_threshold  = $([ "$ENVIRONMENT" = "prod" ] && echo "75" || echo "85")
memory_critical_mb     = $([ "$ENVIRONMENT" = "prod" ] && echo "512" || echo "256")
memory_warning_mb      = $([ "$ENVIRONMENT" = "prod" ] && echo "1024" || echo "512")

# Alert Configuration - UPDATE THESE VALUES
alert_email_addresses = [
  "your-email@company.com"
]

# Optional: Slack webhook for notifications
# alert_webhook_url = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Optional: SMS alerts for production
$([ "$ENVIRONMENT" = "prod" ] && echo 'enable_sms_alerts = true' || echo '# enable_sms_alerts = false')
$([ "$ENVIRONMENT" = "prod" ] && echo 'sms_phone_numbers = ["+1234567890"]' || echo '# sms_phone_numbers = []')
EOF
        
        print_success "Sample environment file created: $env_file"
        print_warning "⚠️  IMPORTANT: Please edit this file with your actual values before deploying!"
        print_status "Required changes:"
        print_status "  1. Update subscription_id and tenant_id"
        print_status "  2. Update vmss_resource_groups with your actual resource groups"
        print_status "  3. Update alert_email_addresses with your email"
        print_status "  4. Optionally add Slack webhook and SMS numbers"
        echo
        read -p "Press Enter to continue after updating the file, or Ctrl+C to exit..."
    fi
}

# Main deployment function
main() {
    print_status "Starting VMSS monitoring deployment..."
    print_status "Environment: $ENVIRONMENT"
    print_status "Plan only: $PLAN_ONLY"
    print_status "Auto approve: $AUTO_APPROVE"
    print_status "Destroy: $DESTROY"
    echo
    
    # Run checks and deployment
    check_prerequisites
    
    # Create sample environment file if needed
    create_sample_env_file
    
    validate_terraform
    init_terraform
    
    if plan_terraform; then
        if [[ "$PLAN_ONLY" == "true" ]]; then
            print_success "Plan completed successfully. Remove -p flag to apply."
        else
            apply_terraform
            
            if [[ "$DESTROY" == "false" ]]; then
                print_success "🎉 VMSS monitoring deployment completed successfully!"
                print_status "📊 Next steps:"
                print_status "  1. Check the Azure portal for your new monitoring resources"
                print_status "  2. Verify data is flowing into Log Analytics workspace"
                print_status "  3. Test alert notifications"
                print_status "  4. Access workbooks for monitoring dashboards"
                echo
                print_status "🔗 Useful links:"
                terraform output -json | jq -r '.dashboard_urls.value | to_entries[] | "  \(.key): \(.value)"'
            fi
        fi
    else
        exit 1
    fi
}

# Run main function
main "$@"