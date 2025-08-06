#!/bin/bash

# Script to set up User Assigned Identity for Azure Key Vault access

RESOURCE_GROUP="prod-llm-rg"
KEYVAULT_NAME="prod-llm-keyvault"
IDENTITY_NAME="nginx-keyvault-identity"

echo "🔧 Setting up User Assigned Identity for Key Vault access..."

# Create User Assigned Identity
echo "Creating User Assigned Identity: $IDENTITY_NAME"
az identity create \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME

if [ $? -eq 0 ]; then
    echo "✅ User Assigned Identity created successfully"
    
    # Get the identity details
    IDENTITY_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME --query id -o tsv)
    PRINCIPAL_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME --query principalId -o tsv)
    
    echo "Identity ID: $IDENTITY_ID"
    echo "Principal ID: $PRINCIPAL_ID"
    
    # Assign Key Vault permissions using RBAC
    echo "Assigning Key Vault permissions using RBAC..."
    az role assignment create \
      --assignee $PRINCIPAL_ID \
      --role "Key Vault Secrets User" \
      --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✅ Key Vault permissions assigned successfully"
        
        # Update the values.yaml with the identity ID
        echo "Updating values.yaml with identity ID..."
        sed -i.bak "s/userAssignedIdentityID: \"\"/userAssignedIdentityID: \"$IDENTITY_ID\"/" nginx/values.yaml
        
        echo "✅ Updated nginx/values.yaml with identity ID"
        echo ""
        echo "📝 You can now install the chart with:"
        echo "   helm install my-nginx ./nginx"
        echo ""
        echo "🔑 The chart will now reference secrets from Key Vault without storing them locally!"
        
    else
        echo "❌ Failed to assign Key Vault permissions"
        exit 1
    fi
    
else
    echo "❌ Failed to create User Assigned Identity"
    exit 1
fi 