# Bootstrap Core Applications

This directory contains the core applications deployed via the App of Apps pattern in ArgoCD.

## Architecture Overview

The bootstrap process follows a hierarchical structure:

1. **bootstrap-apps.yaml** - Root App of Apps that manages all core components
2. **Core Applications** (this directory):
   - `namespaces.yaml` - Namespace management and resource quotas
   - `pulumi-operator.yaml` - Pulumi Kubernetes Operator via Helm
   - `infrastructure.yaml` - Infrastructure deployment orchestration

## App of Apps Pattern

```
bootstrap-apps.yaml (sync-wave: 0)
├── namespaces.yaml (sync-wave: 0)
├── pulumi-operator.yaml (sync-wave: 1)
└── infrastructure.yaml (sync-wave: 2)
    └── infrastructure/stacks/ (sync-wave: 3)
```

## Sync Waves

- **Wave 0**: Namespaces and resource quotas
- **Wave 1**: Core operators (Pulumi)
- **Wave 2**: Bootstrap infrastructure applications
- **Wave 3**: Actual infrastructure stacks (Pulumi Stack CRDs)

## Benefits

- **Separation of Concerns**: Each component is managed independently
- **Proper Dependency Management**: Sync waves ensure correct startup order
- **Resource Isolation**: Proper namespaces and quotas
- **Security**: Pod Security Standards and RBAC
- **Observability**: Individual application health and status
