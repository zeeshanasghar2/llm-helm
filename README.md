# Azure Key Vault Integration with AKS

This guide explains how to integrate Azure Key Vault with AKS using the CSI Secret Store Driver. This assumes you already have:
- AKS cluster with CSI driver addon enabled
- Azure Key Vault with RBAC authentication
- CSI driver managed identity in MC_ resource group

## Prerequisites

- Azure CLI
- kubectl
- Helm v3

## Step 1: Create a Secret in Azure Key Vault

```bash
# Create a secret in Key Vault
az keyvault secret set \
  --vault-name "your-keyvault-name" \
  --name "my-secret" \
  --value "my-secret-value"
```

## Step 2: Assign RBAC Role to CSI Driver Identity

1. Get the CSI driver's managed identity client ID:
```bash
export IDENTITY_CLIENT_ID=$(az aks show -g <resource-group> -n <cluster-name> \
  --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" -o tsv)
```

2. Get the Key Vault resource ID:
```bash
export KEYVAULT_ID=$(az keyvault show -g <resource-group> -n <keyvault-name> \
  --query "id" -o tsv)
```

3. Assign "Key Vault Secrets User" role:
```bash
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $IDENTITY_CLIENT_ID \
  --scope $KEYVAULT_ID
```

## Step 3: Create Required Kubernetes Manifests

### values.yaml
```yaml
replicaCount: 1
image: nginx:1.16.0
servicePort: 80

keyVault:
  enabled: true
  name: "your-keyvault-name"
  secretName: "my-secret"
  envName: "MY_SECRET"
  tenantId: "your-tenant-id"  # Get with: az account show --query tenantId -o tsv
```

### secretproviderclass.yaml
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: {{ .Release.Name }}-keyvault-spc
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "True"
    userAssignedIdentityID: "your-csi-client-id"  # Get from Step 2
    keyvaultName: "{{ .Values.keyVault.name }}"
    objects: |
      array:
        - |
          objectName: {{ .Values.keyVault.secretName }}
          objectType: secret
          objectVersion: ""
    tenantId: "{{ .Values.keyVault.tenantId }}"
  secretObjects:
  - data:
    - key: {{ .Values.keyVault.secretName }}
      objectName: {{ .Values.keyVault.secretName }}
    secretName: {{ .Release.Name }}-keyvault-secret
    type: Opaque
```

### deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-nginx
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      serviceAccountName: default
      containers:
      - name: nginx
        image: {{ .Values.image }}
        ports:
        - containerPort: 80
        {{- if .Values.keyVault.enabled }}
        env:
        - name: {{ .Values.keyVault.envName }}
          valueFrom:
            secretKeyRef:
              name: {{ .Release.Name }}-keyvault-secret
              key: {{ .Values.keyVault.secretName }}
        volumeMounts:
        - name: secrets-store-inline
          mountPath: "/mnt/secrets-store"
          readOnly: true
        {{- end }}
      {{- if .Values.keyVault.enabled }}
      volumes:
      - name: secrets-store-inline
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: {{ .Release.Name }}-keyvault-spc
      {{- end }}
```

## Step 4: Deploy the Helm Chart

```bash
# Install the chart
helm install my-app ./

# Verify pod is running
kubectl get pods

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=nginx
```

## Step 5: Verify Secret Access

1. Check if secret is mounted as a file:
```bash
# Get pod name
POD_NAME=$(kubectl get pod -l app=nginx -o jsonpath='{.items[0].metadata.name}')

# Check mounted secret
kubectl exec $POD_NAME -- cat /mnt/secrets-store/my-secret
```

2. Check if secret is available as environment variable:
```bash
# Check environment variable
kubectl exec $POD_NAME -- env | grep MY_SECRET
```

## Example Test Results

```bash
$ kubectl exec my-nginx-nginx-749b44f95d-bzz7r -- cat /mnt/secrets-store/my-secret
my-secret-value

$ kubectl exec my-nginx-nginx-749b44f95d-bzz7r -- env | grep MY_SECRET
MY_SECRET=my-secret-value
```

## Troubleshooting

1. Check pod events:
```bash
kubectl describe pod <pod-name>
```

2. Check CSI driver logs:
```bash
kubectl logs -n kube-system -l app=secrets-store-csi-driver
```

3. Common issues:
   - Secret not found: Verify secret exists in Key Vault
   - Permission denied: Check RBAC role assignment
   - Identity not found: Verify CSI driver identity ID
   - Mount failure: Check SecretProviderClass configuration
