# =========================================================
# MAIN TERRAFORM CONFIGURATION FOR VMSS MONITORING
# =========================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }

  # Configure backend for state management
  backend "azurerm" {
    # Values provided via backend config file or environment variables
    # resource_group_name  = "rg-terraform-state"
    # storage_account_name = "tfstatexxxxxx"
    # container_name       = "tfstate"
    # key                  = "vmss-monitoring.terraform.tfstate"
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    log_analytics_workspace {
      permanently_delete_on_destroy = var.environment != "production"
    }
  }
  
  subscription_id = var.subscription_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# =========================================================
# DATA SOURCES
# =========================================================

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Get existing VMSS resource groups
data "azurerm_resource_group" "vmss_groups" {
  for_each = toset(var.vmss_resource_groups)
  name     = each.value
}

# Get existing VMSS instances for monitoring setup
data "azurerm_virtual_machine_scale_set" "vmss_instances" {
  for_each            = toset(var.vmss_names)
  name                = each.value
  resource_group_name = var.vmss_resource_groups[index(var.vmss_names, each.value)]
}

# =========================================================
# RESOURCE GROUP FOR MONITORING INFRASTRUCTURE
# =========================================================

resource "azurerm_resource_group" "monitoring" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    Purpose     = "VMSS Monitoring"
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CreatedBy   = data.azurerm_client_config.current.object_id
  }
}

# =========================================================
# LOG ANALYTICS WORKSPACE MODULE
# =========================================================

module "log_analytics" {
  source = "./modules/log-analytics"

  resource_group_name = azurerm_resource_group.monitoring.name
  location           = azurerm_resource_group.monitoring.location
  workspace_name     = var.workspace_name
  retention_days     = var.retention_days
  daily_quota_gb     = var.daily_quota_gb
  environment        = var.environment
  
  tags = {
    Environment = var.environment
    Purpose     = "VMSS Monitoring"
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# =========================================================
# AZURE MONITOR AGENT CONFIGURATION
# =========================================================

# Data Collection Rule for VMSS monitoring
resource "azurerm_monitor_data_collection_rule" "vmss_monitoring" {
  name                = "dcr-vmss-monitoring-${var.environment}"
  resource_group_name = azurerm_resource_group.monitoring.name
  location           = azurerm_resource_group.monitoring.location
  description        = "Data collection rule for VMSS monitoring"

  destinations {
    log_analytics {
      workspace_resource_id = module.log_analytics.workspace_id
      name                 = "LogAnalyticsDestination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Event", "Microsoft-InsightsMetrics"]
    destinations = ["LogAnalyticsDestination"]
  }

  data_sources {
    performance_counter {
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\Memory\\% Committed Bytes In Use",
        "\\LogicalDisk(_Total)\\% Free Space",
        "\\LogicalDisk(_Total)\\Free Megabytes",
        "\\Network Interface(*)\\Bytes Total/sec",
        "\\System\\Processor Queue Length",
        "\\Web Service(_Total)\\Current Connections",
        "\\Web Service(_Total)\\Get Requests/sec",
        "\\Web Service(_Total)\\Post Requests/sec",
        "\\APP_POOL_WAS(_Total)\\Current Worker Processes"
      ]
      name = "VMSSPerformanceCounters"
    }

    windows_event_log {
      streams = ["Microsoft-Event"]
      x_path_queries = [
        "System!*[System[(EventID=7034 or EventID=7035 or EventID=7036 or EventID=7040)]]",
        "Application!*[System[Level=1 or Level=2]]",
        "Microsoft-Windows-IIS-Logging/Logs!*[System[Level=1 or Level=2]]"
      ]
      name = "VMSSEventLogs"
    }

    extension {
      streams            = ["Microsoft-InsightsMetrics"]
      extension_name     = "Microsoft-InsightsMetrics"
      extension_json = jsonencode({
        "dataSources" = {
          "performanceCounters" = [
            {
              "streams" = ["Microsoft-InsightsMetrics"]
              "scheduledTransferPeriod" = "PT1M"
              "samplingFrequencyInSeconds" = 60
              "counterSpecifiers" = [
                "\\VmInsights\\DetailedMetrics"
              ]
            }
          ]
        }
      })
      name = "VMSSInsightsMetrics"
    }
  }

  tags = {
    Environment = var.environment
    Purpose     = "VMSS Monitoring"
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# =========================================================
# ASSOCIATE DATA COLLECTION RULE WITH VMSS
# =========================================================

resource "azurerm_monitor_data_collection_rule_association" "vmss_association" {
  for_each                    = data.azurerm_virtual_machine_scale_set.vmss_instances
  name                       = "dcra-${each.key}-monitoring"
  target_resource_id         = each.value.id
  data_collection_rule_id    = azurerm_monitor_data_collection_rule.vmss_monitoring.id
  description               = "Associate VMSS ${each.key} with monitoring DCR"
}

# =========================================================
# ALERTS MODULE
# =========================================================

module "alerts" {
  source = "./modules/alerts"

  resource_group_name     = azurerm_resource_group.monitoring.name
  location               = azurerm_resource_group.monitoring.location
  workspace_id           = module.log_analytics.workspace_id
  workspace_name         = module.log_analytics.workspace_name
  environment            = var.environment
  
  # Alert configuration
  alert_email_addresses  = var.alert_email_addresses
  alert_webhook_url      = var.alert_webhook_url
  pagerduty_integration_key = var.pagerduty_integration_key
  
  # Threshold configuration
  cpu_critical_threshold    = var.cpu_critical_threshold
  cpu_warning_threshold     = var.cpu_warning_threshold
  memory_critical_mb        = var.memory_critical_mb
  memory_warning_mb         = var.memory_warning_mb
  disk_critical_percent     = var.disk_critical_percent
  disk_warning_percent      = var.disk_warning_percent
  instance_offline_minutes  = var.instance_offline_minutes
  health_percentage_red     = var.health_percentage_red
  health_percentage_amber   = var.health_percentage_amber

  # VMSS configuration
  vmss_resource_groups = var.vmss_resource_groups
  
  tags = {
    Environment = var.environment
    Purpose     = "VMSS Monitoring"
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.log_analytics]
}

# =========================================================
# WORKBOOKS MODULE
# =========================================================

module "workbooks" {
  source = "./modules/workbooks"

  resource_group_name = azurerm_resource_group.monitoring.name
  location           = azurerm_resource_group.monitoring.location
  workspace_id       = module.log_analytics.workspace_id
  workspace_name     = module.log_analytics.workspace_name
  environment        = var.environment
  
  # Workbook configuration
  vmss_resource_groups = var.vmss_resource_groups
  
  tags = {
    Environment = var.environment
    Purpose     = "VMSS Monitoring"
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  depends_on = [module.log_analytics]
}

# =========================================================
# RBAC - MONITORING READER ROLE FOR VMSS RESOURCE GROUPS
# =========================================================

# Create custom role for VMSS monitoring
resource "azurerm_role_definition" "vmss_monitoring" {
  name  = "VMSS Monitoring Reader - ${var.environment}"
  scope = "/subscriptions/${var.subscription_id}"

  description = "Custom role for VMSS monitoring with required permissions"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachineScaleSets/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/networkInterfaces/read",
      "Microsoft.Insights/MetricDefinitions/read",
      "Microsoft.Insights/Metrics/read",
      "Microsoft.OperationalInsights/workspaces/read",
      "Microsoft.OperationalInsights/workspaces/query/action",
      "Microsoft.Resources/subscriptions/resourceGroups/read"
    ]
    not_actions = []
  }

  assignable_scopes = [
    "/subscriptions/${var.subscription_id}"
  ]
}

# Assign monitoring role to Log Analytics workspace managed identity
resource "azurerm_role_assignment" "vmss_monitoring" {
  for_each             = toset(var.vmss_resource_groups)
  scope                = data.azurerm_resource_group.vmss_groups[each.key].id
  role_definition_id   = azurerm_role_definition.vmss_monitoring.role_definition_resource_id
  principal_id         = module.log_analytics.workspace_identity_principal_id
  
  depends_on = [azurerm_role_definition.vmss_monitoring]
}

# =========================================================
# SAVED SEARCHES (KQL QUERIES)
# =========================================================

# Main RAG Status Dashboard Query
resource "azurerm_log_analytics_saved_search" "rag_status" {
  name                       = "VMSS-RAG-Status-Dashboard"
  log_analytics_workspace_id = module.log_analytics.workspace_id
  category                   = "VMSS Monitoring"
  display_name              = "VMSS RAG Status Dashboard"
  query                     = file("${path.module}/../kql-queries/main-dashboard/vmss-rag-status.kql")

  tags = {
    Environment = var.environment
    Purpose     = "Main Dashboard"
    Type        = "RAG Status"
  }
}

# Instance Drill-down Query
resource "azurerm_log_analytics_saved_search" "instance_drilldown" {
  name                       = "VMSS-Instance-Drilldown"
  log_analytics_workspace_id = module.log_analytics.workspace_id
  category                   = "VMSS Monitoring"
  display_name              = "VMSS Instance Drill-down Analysis"
  query                     = file("${path.module}/../kql-queries/supporting-queries/instance-drilldown.kql")

  tags = {
    Environment = var.environment
    Purpose     = "Detailed Analysis"
    Type        = "Instance Health"
  }
}

# Performance Trends Query
resource "azurerm_log_analytics_saved_search" "performance_trends" {
  name                       = "VMSS-Performance-Trends"
  log_analytics_workspace_id = module.log_analytics.workspace_id
  category                   = "VMSS Monitoring"
  display_name              = "VMSS Performance Trends Analysis"
  query                     = file("${path.module}/../kql-queries/supporting-queries/performance-trends.kql")

  tags = {
    Environment = var.environment
    Purpose     = "Trend Analysis"
    Type        = "Performance"
  }
}

# Capacity Planning Query
resource "azurerm_log_analytics_saved_search" "capacity_planning" {
  name                       = "VMSS-Capacity-Planning"
  log_analytics_workspace_id = module.log_analytics.workspace_id
  category                   = "VMSS Monitoring"
  display_name              = "VMSS Capacity Planning Recommendations"
  query                     = file("${path.module}/../kql-queries/supporting-queries/capacity-planning.kql")

  tags = {
    Environment = var.environment
    Purpose     = "Capacity Planning"
    Type        = "Recommendations"
  }
}

# =========================================================
# DIAGNOSTIC SETTINGS FOR VMSS
# =========================================================

# Enable diagnostic settings for each VMSS
resource "azurerm_monitor_diagnostic_setting" "vmss_diagnostics" {
  for_each                   = data.azurerm_virtual_machine_scale_set.vmss_instances
  name                       = "diag-${each.key}-monitoring"
  target_resource_id         = each.value.id
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enabled_log {
    category = "AutoscaleEvaluations"
  }

  enabled_log {
    category = "AutoscaleScaleActions"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# =========================================================
# DASHBOARD AUTOMATION
# =========================================================

# Create Action Group for dashboard refresh automation
resource "azurerm_monitor_action_group" "dashboard_automation" {
  name                = "ag-dashboard-automation-${var.environment}"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "DashAutomate"

  automation_runbook_receiver {
    name                    = "RefreshDashboard"
    automation_account_id   = var.automation_account_id
    runbook_name           = "Refresh-VMSSDashboard"
    webhook_resource_id    = var.automation_webhook_id
    is_global_runbook      = false
    service_uri            = var.automation_webhook_uri
    use_common_alert_schema = true
  }

  tags = {
    Environment = var.environment
    Purpose     = "Dashboard Automation"
    ManagedBy   = "Terraform"
  }
}

# =========================================================
# OUTPUT VALUES
# =========================================================

output "monitoring_resource_group_name" {
  description = "Name of the monitoring resource group"
  value       = azurerm_resource_group.monitoring.name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.log_analytics.workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = module.log_analytics.workspace_name
}

output "data_collection_rule_id" {
  description = "ID of the data collection rule"
  value       = azurerm_monitor_data_collection_rule.vmss_monitoring.id
}

output "workbook_ids" {
  description = "IDs of created workbooks"
  value       = module.workbooks.workbook_ids
}

output "alert_rule_ids" {
  description = "IDs of created alert rules"
  value       = module.alerts.alert_rule_ids
}

output "dashboard_urls" {
  description = "URLs for accessing monitoring dashboards"
  value = {
    rag_dashboard        = "https://portal.azure.com/#@${var.tenant_id}/resource${module.workbooks.rag_dashboard_id}"
    performance_analysis = "https://portal.azure.com/#@${var.tenant_id}/resource${module.workbooks.performance_workbook_id}"
    capacity_planning    = "https://portal.azure.com/#@${var.tenant_id}/resource${module.workbooks.capacity_workbook_id}"
    log_analytics       = "https://portal.azure.com/#@${var.tenant_id}/resource${module.log_analytics.workspace_id}"
  }
}