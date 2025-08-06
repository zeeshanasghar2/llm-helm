# Nginx Helm Chart with Azure Key Vault CSI Integration

A Helm chart for deploying Nginx with secure Azure Key Vault secret integration using CSI Driver.

## 🔐 Azure Key Vault Integration

This chart uses **Azure Secrets Store CSI Driver** to securely reference secrets from Azure Key Vault without storing them locally.

### Prerequisites

1. **Azure Key Vault** with secrets
2. **AKS CSI Driver Managed Identity** with Key Vault permissions (no user-assigned identity needed)
3. **Azure Secrets Store CSI Driver** (already installed on your cluster)

### Setup

1. **Ensure the CSI driver managed identity has Key Vault access**
   - Assign the "Key Vault Secrets User" role to the managed identity for your Key Vault

2. **Install the chart:**
   ```bash
   helm install my-nginx ./nginx
   ```

## Install without Key Vault

```bash
helm install my-nginx ./nginx --set keyVault.enabled=false
```

## Uninstall

```bash
helm uninstall my-nginx
```

## Configuration

- `replicaCount`: Number of replicas (default: 1)
- `image`: Nginx image (default: nginx:1.16.0)
- `servicePort`: Service port (default: 80)
- `keyVault.enabled`: Enable Key Vault integration (default: true)
- `keyVault.name`: Azure Key Vault name
- `keyVault.secretName`: Secret name in Key Vault
- `keyVault.envName`: Environment variable name for the secret
- `keyVault.tenantId`: Azure tenant ID

## How It Works

1. **SecretProviderClass**: Defines how to access Azure Key Vault
2. **CSI Volume**: Mounts secrets from Key Vault as files
3. **Environment Variable**: Makes the secret available to the application
4. **No Local Storage**: Secrets are never stored in the chart or cluster

## Security Benefits

- ✅ Secrets never stored locally
- ✅ Automatic rotation from Key Vault
- ✅ Fine-grained access control
- ✅ Audit trail in Azure Key Vault
- ✅ No secret values in Helm values files 