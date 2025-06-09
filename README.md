# Azure VMSS Monitoring Solution

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Terraform](https://img.shields.io/badge/terraform-v1.0+-purple.svg)
![Azure](https://img.shields.io/badge/azure-monitor-blue.svg)

A comprehensive monitoring solution for Azure Virtual Machine Scale Sets (VMSS) with RAG (Red-Amber-Green) status dashboard, automated alerting, and capacity planning.

## 🎯 Features

- **RAG Status Dashboard** - Real-time health monitoring with color-coded status
- **Automated Alerting** - Multi-tier alerting for critical issues
- **Performance Analytics** - CPU, Memory, Disk, and Network monitoring
- **Capacity Planning** - Scaling recommendations and trend analysis
- **Infrastructure as Code** - Complete Terraform deployment
- **Multi-Environment Support** - Dev, Staging, Production configurations

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed and authenticated
- Terraform >= 1.0
- Azure subscription with appropriate permissions
- VMSS instances with Azure Monitor Agent installed

### 1. Clone Repository
```bash
git clone <your-repo-url>
cd azure-vmss-monitoring
```

### 2. Configure Environment
```bash
# Copy environment template
cp terraform/environments/prod.tfvars.example terraform/environments/prod.tfvars

# Edit with your values
vi terraform/environments/prod.tfvars
```

### 3. Deploy Infrastructure
```bash
cd terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="environments/prod.tfvars"

# Deploy
terraform apply -var-file="environments/prod.tfvars"
```

### 4. Import Workbooks
```bash
# Use Azure CLI to import workbooks
az monitor app-insights workbook create \
  --resource-group <rg-name> \
  --name "VMSS RAG Dashboard" \
  --category "workbook" \
  --source-id "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.OperationalInsights/workspaces/<workspace-name>" \
  --template-data @workbooks/vmss-rag-dashboard.json
```

## 📊 Dashboard Overview

### Main RAG Status Dashboard
The primary monitoring view shows:
- **🟢 GREEN** - All systems healthy
- **🟡 AMBER** - Warning conditions detected  
- **🔴 RED** - Critical issues requiring immediate attention

### Key Metrics Monitored
- **Instance Health** - Availability and heartbeat status
- **CPU Performance** - Utilization trends and hotspots
- **Memory Usage** - Available memory and pressure indicators
- **Disk Space** - Free space monitoring across drives
- **Network Performance** - Throughput and connectivity
- **Application Services** - Windows services and IIS health
- **Auto-scaling Events** - Scaling operations and success rates

## 🏗️ Architecture

### Monitoring Components
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   VMSS Fleet    │───▶│  Log Analytics   │───▶│   Workbooks     │
│                 │    │   Workspace      │    │   Dashboards    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  Alert Rules     │
                       │  & Action Groups │
                       └──────────────────┘
```

### Data Flow
1. **Azure Monitor Agent** collects metrics from VMSS instances
2. **Log Analytics Workspace** stores and processes telemetry data
3. **KQL Queries** analyze data and calculate RAG status
4. **Workbooks** provide interactive dashboards
5. **Alert Rules** trigger notifications for issues
6. **Action Groups** handle incident response

## 📁 Project Structure

```
├── terraform/          # Infrastructure as Code
│   ├── modules/        # Reusable Terraform modules
│   └── environments/   # Environment-specific configs
├── kql-queries/        # All monitoring queries
│   ├── main-dashboard/ # Primary RAG dashboard queries
│   ├── supporting-queries/ # Detailed analysis queries
│   └── alert-queries/  # Alert condition queries
├── workbooks/          # Azure Workbook templates
├── docs/               # Documentation
└── scripts/            # Deployment and utility scripts
```

## 🔧 Configuration

### Environment Variables
Key variables to configure in your `.tfvars` file:

```hcl
# Basic Configuration
subscription_id     = "your-subscription-id"
resource_group_name = "rg-monitoring-prod"
location           = "East US"
environment        = "production"

# Log Analytics
workspace_name = "law-vmss-monitoring-prod"
retention_days = 90

# VMSS Configuration
vmss_resource_groups = [
  "rg-web-prod",
  "rg-api-prod", 
  "rg-workers-prod"
]

# Alert Configuration
alert_email_addresses = [
  "ops-team@company.com",
  "devops@company.com"
]

# Thresholds
cpu_critical_threshold = 85
cpu_warning_threshold  = 75
memory_critical_mb     = 512
memory_warning_mb      = 1024
```

### Custom Thresholds
Modify thresholds in `kql-queries/main-dashboard/vmss-rag-status.kql`:

```kql
let CPUCriticalThreshold = 85.0;     // Your CPU critical %
let CPUWarningThreshold = 75.0;      // Your CPU warning %
let MemoryCriticalMB = 512;          // Your memory critical MB
let MemoryWarningMB = 1024;          // Your memory warning MB
```

## 🚨 Alert Configuration

### Alert Severity Levels

| Level | Condition | Response Time | Action |
|-------|-----------|---------------|---------|
| **Critical** | VMSS status RED | Immediate | PagerDuty + Email + SMS |
| **Warning** | VMSS status AMBER | 15 minutes | Email notification |
| **Info** | Status recovery | N/A | Email notification |

### Custom Alert Rules
Create additional alerts by modifying `terraform/modules/alerts/main.tf`:

```hcl
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "custom_alert" {
  name                = "Custom VMSS Alert"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  criteria {
    query = file("${path.module}/../../../kql-queries/alert-queries/custom-alert.kql")
    # ... additional configuration
  }
}
```

## 📈 Usage Examples

### View Current VMSS Status
```bash
# Query current RAG status
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query @kql-queries/main-dashboard/vmss-rag-status.kql
```

### Investigate Specific VMSS
```bash
# Drill down into specific VMSS issues
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query @kql-queries/supporting-queries/instance-drilldown.kql \
  --query-parameters VMSSName="vmss-web-prod"
```

### Performance Trend Analysis
```bash
# Analyze 24-hour performance trends
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query @kql-queries/supporting-queries/performance-trends.kql
```

## 🔍 Troubleshooting

### Common Issues

#### No Data Appearing
1. **Check Azure Monitor Agent**: Ensure agent is installed and running
2. **Verify Permissions**: Confirm monitoring identity has required roles
3. **Check Workspace**: Verify Log Analytics workspace is receiving data

```bash
# Check agent status
az vm extension show \
  --resource-group <rg-name> \
  --vm-name <vm-name> \
  --name AzureMonitorWindowsAgent
```

#### Incorrect RAG Status
1. **Review Thresholds**: Check if thresholds match your requirements
2. **Validate Queries**: Test queries manually in Log Analytics
3. **Check Data Freshness**: Ensure recent data is available

#### Alerts Not Firing
1. **Verify Alert Rules**: Check alert rule configuration
2. **Test Action Groups**: Send test notifications
3. **Check Query Logic**: Validate alert query conditions

### Debug Commands
```bash
# Test Log Analytics connectivity
az monitor log-analytics workspace show \
  --resource-group <rg-name> \
  --workspace-name <workspace-name>

# List VMSS instances
az vmss list --output table

# Check alert rules
az monitor metrics alert list \
  --resource-group <rg-name> \
  --output table
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-monitoring`
3. **Make changes and test thoroughly**
4. **Submit pull request with detailed description**

### Development Guidelines
- Follow Terraform best practices
- Test KQL queries before committing
- Update documentation for new features
- Include examples for custom configurations

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:
1. **Check troubleshooting guide**: [docs/troubleshooting.md](docs/troubleshooting.md)
2. **Review known issues**: GitHub Issues tab
3. **Create new issue**: Provide detailed logs and configuration

## 🎯 Roadmap

- [ ] **Azure DevOps integration**
- [ ] **Slack/Teams notifications**
- [ ] **Custom metric collection**
- [ ] **Multi-subscription support**
- [ ] **PowerBI integration**
- [ ] **Automated remediation**

---

**Need help?** Check out our [Setup Guide](docs/setup-guide.md) and [Deployment Guide](docs/deployment-guide.md) for detailed instructions.