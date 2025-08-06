#!/bin/bash

# Setup Workload Identity for Azure Key Vault access
# This script creates the necessary Azure resources for Workload Identity

set -e

# Configuration
RESOURCE_GROUP="dev-llm-rg"
LOCATION="eastus"
CLUSTER_NAME="dev-llm-aks"
KEYVAULT_NAME="dev-llm-keyvault"
MANAGED_IDENTITY_NAME="llm-workload-identity"
SERVICE_ACCOUNT_NAME="openwebui-stack-sa"
SERVICE_ACCOUNT_NAMESPACE="openwebui-stack"

echo "Setting up Workload Identity for Azure Key Vault access..."

# 1. Create managed identity
echo "Creating managed identity..."
az identity create \
  --resource-group $RESOURCE_GROUP \
  --name $MANAGED_IDENTITY_NAME \
  --location $LOCATION

# Get the managed identity details
MANAGED_IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $MANAGED_IDENTITY_NAME \
  --query clientId -o tsv)

MANAGED_IDENTITY_TENANT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $MANAGED_IDENTITY_NAME \
  --query tenantId -o tsv)

MANAGED_IDENTITY_PRINCIPAL_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $MANAGED_IDENTITY_NAME \
  --query principalId -o tsv)

echo "Managed Identity Client ID: $MANAGED_IDENTITY_CLIENT_ID"
echo "Managed Identity Tenant ID: $MANAGED_IDENTITY_TENANT_ID"

# 2. Get AKS OIDC Issuer URL
echo "Getting AKS OIDC Issuer URL..."
OIDC_ISSUER=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query oidcIssuerProfile.issuerUrl -o tsv)

echo "OIDC Issuer URL: $OIDC_ISSUER"

# 3. Create federated identity credential
echo "Creating federated identity credential..."
az identity federated-credential create \
  --name "llm-federated-credential" \
  --identity-name $MANAGED_IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:$SERVICE_ACCOUNT_NAMESPACE:$SERVICE_ACCOUNT_NAME" \
  --audience api://AzureADTokenExchange

# 4. Assign Key Vault permissions to managed identity
echo "Assigning Key Vault permissions..."
az keyvault set-policy \
  --name $KEYVAULT_NAME \
  --secret-permissions get list \
  --object-id $MANAGED_IDENTITY_PRINCIPAL_ID

echo "Workload Identity setup complete!"
echo ""
echo "Update your secret-store-provider.yaml with these values:"
echo "clientID: $MANAGED_IDENTITY_CLIENT_ID"
echo "tenantId: $MANAGED_IDENTITY_TENANT_ID"
echo ""
echo "Then apply the updated configuration:"
echo "kubectl apply -f secret-store-provider.yaml" 