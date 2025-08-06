# llm-helm
A Helm chart for deploying a full AI stack with OpenWebUI, LiteLLM, and Ollama.

## Overview

This Helm chart deploys a complete AI stack including:
- **OpenWebUI**: A modern web UI for AI models
- **LiteLLM**: A unified API for multiple LLM providers
- **Ollama**: Local LLM inference server

## Prerequisites

- Kubernetes cluster with CSI driver support
- Azure Key Vault with secrets stored
- Azure Workload Identity configured
- Secret Store CSI Driver installed

## Azure Key Vault Integration

This chart uses Azure Key Vault for secret management via the Secret Store CSI Driver. The following secrets must be stored in your Azure Key Vault:

### Required Secrets

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `postgresql-admin-password` | PostgreSQL admin password | `your-secure-password` |
| `postgresql-admin-username` | PostgreSQL admin username | `postgres` |
| `postgresql-database` | Database name | `openwebui` |
| `postgresql-host` | PostgreSQL host | `your-host.postgres.database.azure.com` |
| `postgresql-port` | PostgreSQL port | `5432` |
| `webui-secret-key` | OpenWebUI session secret | `your-random-secret-key` |
| `litellm-master-key` | LiteLLM master key | `your-litellm-master-key` |

### Setup Instructions

1. **Create Azure Key Vault secrets:**
   ```bash
   az keyvault secret set --vault-name dev-llm-keyvault --name postgresql-admin-password --value "your-password"
   az keyvault secret set --vault-name dev-llm-keyvault --name postgresql-admin-username --value "postgres"
   az keyvault secret set --vault-name dev-llm-keyvault --name postgresql-database --value "openwebui"
   az keyvault secret set --vault-name dev-llm-keyvault --name postgresql-host --value "your-host.postgres.database.azure.com"
   az keyvault secret set --vault-name dev-llm-keyvault --name postgresql-port --value "5432"
   az keyvault secret set --vault-name dev-llm-keyvault --name webui-secret-key --value "your-random-secret-key"
   az keyvault secret set --vault-name dev-llm-keyvault --name litellm-master-key --value "your-litellm-master-key"
   ```

2. **Install Secret Store CSI Driver:**
   ```bash
   helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
   helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system
   ```

3. **Install Azure CSI Driver:**
   ```bash
   helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
   helm install azure-csi-provider csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --namespace kube-system
   ```

4. **Configure Workload Identity:**
   - Create a managed identity
   - Assign Key Vault permissions to the managed identity
   - Update the `clientID` and `tenantId` in `secret-store-provider.yaml`

## Installation

1. **Apply the SecretProviderClass:**
   ```bash
   kubectl apply -f secret-store-provider.yaml
   ```

2. **Install the Helm chart:**
   ```bash
   helm install llm-stack . --namespace default
   ```

## Configuration

The chart can be configured using the `values.yaml` file. Key configuration options include:

- **OpenWebUI**: Web UI configuration, resources, and probes
- **LiteLLM**: API proxy configuration and resources
- **Ollama**: Local LLM server configuration and model selection
- **Persistence**: Storage configuration for Ollama models

## Security

- All secrets are stored in Azure Key Vault and mounted securely via CSI driver
- No secrets are stored in the Helm chart or Git repository
- Workload Identity provides secure authentication to Azure Key Vault
- Secrets are mounted as files and read by the applications at runtime

## Troubleshooting

1. **Check SecretProviderClass status:**
   ```bash
   kubectl get secretproviderclass azure-kv-secrets -o yaml
   ```

2. **Check pod events:**
   ```bash
   kubectl describe pod <pod-name>
   ```

3. **Verify secrets are mounted:**
   ```bash
   kubectl exec -it <pod-name> -- ls -la /mnt/secrets-store/
   ```

## Components

- **OpenWebUI**: Modern web interface for AI models
- **LiteLLM**: Unified API proxy for multiple LLM providers
- **Ollama**: Local LLM inference server
- **PostgreSQL**: Database for OpenWebUI (external)
