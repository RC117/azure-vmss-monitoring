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
