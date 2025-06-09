# =========================================================
# DEVELOPMENT ENVIRONMENT CONFIGURATION
# Copy this file to dev.tfvars and update with your values
# =========================================================

# Azure Configuration - REQUIRED: UPDATE THESE VALUES
subscription_id = "12345678-1234-1234-1234-123456789abc"  # Replace with your Azure subscription ID
tenant_id       = "87654321-4321-4321-4321-cba987654321"  # Replace with your Azure tenant ID
location        = "East US"                                # Your preferred Azure region

# Project Configuration
environment         = "dev"
project_name        = "vmss-monitoring"
resource_group_name = "rg-vmss-monitoring-dev"
workspace_name      = "law-vmss-monitoring-dev"

# Log Analytics Configuration
retention_days    = 30    # Development: 30 days retention
daily_quota_gb    = 5     # Development: 5GB daily limit

# VMSS Configuration - REQUIRED: UPDATE THESE VALUES
vmss_resource_groups = [
  "rg-web-dev",           # Replace with your actual VMSS resource groups
  "rg-api-dev"            # Add all resource groups containing VMSS to monitor
]

# Optional: Specific VMSS names (will auto-discover if empty)
vmss_names = [
  # "vmss-web-dev",       # Uncomment and specify if you want to monitor specific VMSS
  # "vmss-api-dev"
]

# Monitoring Thresholds (Development - More Relaxed)
cpu_critical_threshold    = 95    # High threshold for dev (95%)
cpu_warning_threshold     = 85    # Warning threshold for dev (85%)
memory_critical_mb        = 256   # Low threshold for dev (256MB)
memory_warning_mb         = 512   # Warning threshold for dev (512MB)
disk_critical_percent     = 5     # Very low disk space (5%)
disk_warning_percent      = 10    # Warning disk space (10%)
instance_offline_minutes  = 10    # Relaxed offline detection (10 minutes)
health_percentage_red     = 50    # Lower health threshold for dev (50%)
health_percentage_amber   = 75    # Amber health threshold for dev (75%)

# Alert Configuration - REQUIRED: UPDATE THESE VALUES
alert_email_addresses = [
  "your-email@company.com",         # Replace with your email address
  "dev-team@company.com"            # Add additional emails as needed
]

# Optional: Slack/Teams Integration
# Uncomment and update with your webhook URL
# alert_webhook_url = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Optional: SMS Alerts (usually disabled for dev)
enable_sms_alerts = false
sms_phone_numbers = []

# Feature Flags
enable_vm_insights            = true     # Enable detailed VM monitoring
enable_custom_dashboards      = true     # Deploy custom workbooks
enable_capacity_planning      = false    # Disable capacity planning for dev

# Additional Tags (Optional)
additional_tags = {
  CostCenter = "Development"
  Owner      = "DevOps Team"
  Project    = "VMSS Monitoring"
}

# =========================================================
# IMPORTANT NOTES:
# =========================================================
# 1. Replace all placeholder values (subscription_id, tenant_id, etc.)
# 2. Update vmss_resource_groups with your actual resource groups
# 3. Update alert_email_addresses with real email addresses
# 4. Ensure you have proper permissions in the specified resource groups
# 5. Test with development environment first before production
# =========================================================