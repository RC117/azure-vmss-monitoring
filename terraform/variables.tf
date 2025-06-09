# =========================================================
# TERRAFORM VARIABLES FOR VMSS MONITORING
# =========================================================

# =========================================================
# AZURE CONFIGURATION
# =========================================================

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "Subscription ID must be a valid GUID."
  }
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant_id))
    error_message = "Tenant ID must be a valid GUID."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
  validation {
    condition = contains([
      "East US", "East US 2", "West US", "West US 2", "West US 3",
      "Central US", "North Central US", "South Central US", "West Central US",
      "UK South", "UK West", "North Europe", "West Europe",
      "Southeast Asia", "East Asia", "Australia East", "Australia Southeast"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

# =========================================================
# PROJECT CONFIGURATION
# =========================================================

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "vmss-monitoring"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group for monitoring infrastructure"
  type        = string
  validation {
    condition     = length(var.resource_group_name) <= 90 && can(regex("^[a-zA-Z0-9._\\-()]+$", var.resource_group_name))
    error_message = "Resource group name must be valid and less than 90 characters."
  }
}

# =========================================================
# LOG ANALYTICS CONFIGURATION
# =========================================================

variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  validation {
    condition     = length(var.workspace_name) >= 4 && length(var.workspace_name) <= 63
    error_message = "Workspace name must be between 4 and 63 characters."
  }
}

variable "retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 90
  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 730
    error_message = "Retention days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion quota in GB (-1 for unlimited)"
  type        = number
  default     = -1
  validation {
    condition     = var.daily_quota_gb == -1 || (var.daily_quota_gb >= 1 && var.daily_quota_gb <= 1000)
    error_message = "Daily quota must be -1 (unlimited) or between 1 and 1000 GB."
  }
}

# =========================================================
# VMSS CONFIGURATION
# =========================================================

variable "vmss_resource_groups" {
  description = "List of resource groups containing VMSS to monitor"
  type        = list(string)
  validation {
    condition     = length(var.vmss_resource_groups) > 0
    error_message = "At least one VMSS resource group must be specified."
  }
}

variable "vmss_names" {
  description = "List of VMSS names to monitor (optional - will discover automatically if empty)"
  type        = list(string)
  default     = []
}

# =========================================================
# MONITORING THRESHOLDS
# =========================================================

variable "cpu_critical_threshold" {
  description = "CPU utilization threshold for critical alerts (%)"
  type        = number
  default     = 85
  validation {
    condition     = var.cpu_critical_threshold >= 70 && var.cpu_critical_threshold <= 100
    error_message = "CPU critical threshold must be between 70 and 100."
  }
}

variable "cpu_warning_threshold" {
  description = "CPU utilization threshold for warning alerts (%)"
  type        = number
  default     = 75
  validation {
    condition     = var.cpu_warning_threshold >= 50 && var.cpu_warning_threshold <= 90
    error_message = "CPU warning threshold must be between 50 and 90."
  }
}

variable "memory_critical_mb" {
  description = "Available memory threshold for critical alerts (MB)"
  type        = number
  default     = 512
  validation {
    condition     = var.memory_critical_mb >= 256 && var.memory_critical_mb <= 2048
    error_message = "Memory critical threshold must be between 256 and 2048 MB."
  }
}

variable "memory_warning_mb" {
  description = "Available memory threshold for warning alerts (MB)"
  type        = number
  default     = 1024
  validation {
    condition     = var.memory_warning_mb >= 512 && var.memory_warning_mb <= 4096
    error_message = "Memory warning threshold must be between 512 and 4096 MB."
  }
}

variable "disk_critical_percent" {
  description = "Free disk space threshold for critical alerts (%)"
  type        = number
  default     = 10
  validation {
    condition     = var.disk_critical_percent >= 5 && var.disk_critical_percent <= 20
    error_message = "Disk critical threshold must be between 5 and 20 percent."
  }
}

variable "disk_warning_percent" {
  description = "Free disk space threshold for warning alerts (%)"
  type        = number
  default     = 20
  validation {
    condition     = var.disk_warning_percent >= 15 && var.disk_warning_percent <= 40
    error_message = "Disk warning threshold must be between 15 and 40 percent."
  }
}

variable "instance_offline_minutes" {
  description = "Minutes offline before considering instance critical"
  type        = number
  default     = 5
  validation {
    condition     = var.instance_offline_minutes >= 2 && var.instance_offline_minutes <= 30
    error_message = "Instance offline threshold must be between 2 and 30 minutes."
  }
}

variable "health_percentage_red" {
  description = "Overall health percentage threshold for RED status"
  type        = number
  default     = 70
  validation {
    condition     = var.health_percentage_red >= 50 && var.health_percentage_red <= 85
    error_message = "Health percentage RED threshold must be between 50 and 85."
  }
}

variable "health_percentage_amber" {
  description = "Overall health percentage threshold for AMBER status"
  type        = number
  default     = 90
  validation {
    condition     = var.health_percentage_amber >= 80 && var.health_percentage_amber <= 95
    error_message = "Health percentage AMBER threshold must be between 80 and 95."
  }
}

# =========================================================
# ALERT CONFIGURATION
# =========================================================

variable "alert_email_addresses" {
  description = "List of email addresses for alert notifications"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for email in var.alert_email_addresses : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All email addresses must be valid."
  }
}

variable "alert_webhook_url" {
  description = "Webhook URL for alert notifications (e.g., Slack, Teams)"
  type        = string
  default     = ""
}

variable "enable_sms_alerts" {
  description = "Enable SMS alerts for critical issues"
  type        = bool
  default     = false
}

variable "sms_phone_numbers" {
  description = "List of phone numbers for SMS alerts"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for phone in var.sms_phone_numbers : can(regex("^\\+[1-9]\\d{1,14}$", phone))
    ])
    error_message = "Phone numbers must be in international format (+1234567890)."
  }
}

# =========================================================
# FEATURE FLAGS
# =========================================================

variable "enable_vm_insights" {
  description = "Enable VM Insights for detailed monitoring"
  type        = bool
  default     = true
}

variable "enable_custom_dashboards" {
  description = "Deploy custom dashboard templates"
  type        = bool
  default     = true
}

variable "enable_capacity_planning" {
  description = "Enable capacity planning workbooks and queries"
  type        = bool
  default     = true
}

# =========================================================
# TAGGING STRATEGY
# =========================================================

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "VMSS Monitoring"
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# =========================================================
# VALIDATION RULES
# =========================================================

# Ensure CPU warning threshold is less than critical threshold
locals {
  validate_cpu_thresholds = var.cpu_warning_threshold < var.cpu_critical_threshold ? true : tobool("CPU warning threshold must be less than critical threshold")
}

# Ensure memory warning threshold is greater than critical threshold
locals {
  validate_memory_thresholds = var.memory_warning_mb > var.memory_critical_mb ? true : tobool("Memory warning threshold must be greater than critical threshold")
}

# Ensure disk warning threshold is greater than critical threshold
locals {
  validate_disk_thresholds = var.disk_warning_percent > var.disk_critical_percent ? true : tobool("Disk warning threshold must be greater than critical threshold")
}

# Ensure health percentage thresholds are properly ordered
locals {
  validate_health_thresholds = var.health_percentage_amber > var.health_percentage_red ? true : tobool("Health percentage AMBER threshold must be greater than RED threshold")
}