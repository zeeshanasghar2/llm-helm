## To get kubeconfig file
az aks get-credentials --resource-group prod|dev-llm-rg --name prod|dev-llm-aks

# to get tanent iD
az account show --query tenantId -o tsv

# Set environment variables for convenience
export RESOURCE_GROUP="dev-llm-rg"
export AKS_CLUSTER_NAME="dev-llm-aks"
export KEYVAULT_NAME="dev-llm-keyvault"
export MANAGED_IDENTITY_NAME="kv-identity-${AKS_CLUSTER_NAME}"
export K8S_SERVICE_ACCOUNT_NAME="kv-reader-sa"
export K8S_NAMESPACE="default"

# 1. Get the OIDC Issuer URL for your AKS cluster
export AKS_OIDC_ISSUER=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "oidcIssuerProfile.issuerUrl" -o tsv)
echo "OIDC Issuer URL: $AKS_OIDC_ISSUER"

# 2. Create the Azure Managed Identity
az identity create --name $MANAGED_IDENTITY_NAME --resource-group $RESOURCE_GROUP
export MANAGED_IDENTITY_CLIENT_ID=$(az identity show --name $MANAGED_IDENTITY_NAME --resource-group $RESOURCE_GROUP --query "clientId" -o tsv)
export MANAGED_IDENTITY_PRINCIPAL_ID=$(az identity show --name $MANAGED_IDENTITY_NAME --resource-group $RESOURCE_GROUP --query "principalId" -o tsv)
echo "Managed Identity Client ID: $MANAGED_IDENTITY_CLIENT_ID"

# 3. Grant the Managed Identity 'get' and 'list' permissions on secrets in your Key Vault
az keyvault set-policy --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --secret-permissions get list --object-id $MANAGED_IDENTITY_PRINCIPAL_ID

# 4. Establish the federated identity credential (the trust relationship)
az identity federated-credential create --name "kubernetes-federated-credential" \
    --identity-name $MANAGED_IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --issuer $AKS_OIDC_ISSUER \
    --subject "system:serviceaccount:${K8S_NAMESPACE}:${K8S_SERVICE_ACCOUNT_NAME}"