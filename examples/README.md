# Example Configurations for GitOps Infrastructure

This directory contains example configurations for different deployment scenarios and environments.

## Files in this directory:

- `production-config/` - Production environment configuration
- `staging-config/` - Staging environment configuration  
- `aws-credentials-examples/` - Different ways to configure AWS access
- `custom-applications/` - Example custom application deployments
- `multi-environment-setup.md` - Guide for multi-environment GitOps

## Quick Start Examples

### Development Environment
- Use default configurations in the main directories
- Single cluster with dev/test workloads
- Local state management

### Staging Environment  
- Separate AWS account or region
- Automated testing integration
- Git branch-based promotion

### Production Environment
- High availability configuration
- Separate AWS account with strict IAM
- Manual approval workflows
- Backup and disaster recovery

## Customization Patterns

Each example shows different approaches to:
- Environment-specific configurations
- AWS resource sizing and security
- ArgoCD application structuring
- Pulumi stack organization
- RBAC and security policies
