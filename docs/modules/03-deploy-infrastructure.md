---
layout: default
title: "3. Deploy Infrastructure"
nav_order: 5
---

# Module 3 — Deploy Infrastructure
{: .no_toc }

Provision all Azure resources with a single command.
{: .fs-6 .fw-300 }

<details open markdown="block">
  <summary>Table of contents</summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

## 3.1 Pre-flight Checks

Before deploying, verify everything is in place:

```bash
# Verify Azure CLI
az account show --query name --output tsv

# Check GPU availability
az vm list-skus --location indonesiacentral \
  --size Standard_NV36ads_A10_v5 \
  --query "[].{Name:name, Restrictions:restrictions}" --output table

# Check VM availability
az vm list-skus --location indonesiacentral \
  --size Standard_D8s --output table | head -5
```

---

## 3.2 One-Command Deploy

```bash
cd infra
ENV_NAME=dev bash deploy.sh
```

This executes 10 steps in order. Total time: **~20–30 minutes** (GPU VM + driver install is the longest step).

### What gets created

| Step | Resource | Time |
|---|---|---|
| 1. Resource Group | `project-lab-dev` | ~5s |
| 2. Networking | VNet + 3 subnets + 2 NSGs | ~30s |
| 3. Container Registry | `chatbotdevacr` (Basic) | ~15s |
| 4. Key Vault | `chatbot-dev-kv` | ~15s |
| 5. AI Foundry | `chatbot-dev-ai` + embedding deployment | ~60s |
| 6. Qdrant VM | `chatbot-dev-vm` + Docker + Qdrant container | ~5 min |
| 7. Doc Intelligence | Commitment resource + disconnected container | ~3 min |
| 8. GPU VM | `chatbot-dev-gpu` + NVIDIA driver + vLLM | ~10–15 min |
| 9. Container Apps | Environment + backend + frontend | ~3 min |
| 10. RBAC | All managed identity role assignments | ~30s |

---

## 3.3 Step-by-Step Walkthrough

If you prefer to run each step individually (for learning or debugging):

### Step 1 — Resource Group

```bash
bash modules/resource-group.sh
```

Creates the resource group `project-lab-dev` in `indonesiacentral`.

### Step 2 — Networking

```bash
bash modules/vnet.sh
```

Creates:
- VNet `chatbot-dev-vnet` (10.0.0.0/16)
- `vm-subnet` (10.0.1.0/24) — for Qdrant VM
- `gpu-subnet` (10.0.2.0/24) — for GPU VM
- `apps-subnet` (10.0.3.0/27) — for Container Apps
- NSG rules restricting Qdrant (6333/6334) and vLLM (8000) to VNet-only

### Step 3 — Container Registry

```bash
bash modules/acr.sh
```

Creates ACR `chatbotdevacr` with Basic SKU. Admin access disabled — uses managed identity.

### Step 4 — Key Vault

```bash
bash modules/keyvault.sh
```

Creates Key Vault `chatbot-dev-kv` with RBAC authorization mode.

### Step 5 — AI Foundry

```bash
bash modules/ai-foundry.sh
```

Creates Azure AI Foundry account and deploys the `text-embedding-3-small` model.

### Step 6 — Qdrant VM

```bash
bash modules/vm.sh
```

Provisions `Standard_D8s_v5` VM with Ubuntu 22.04, installs Docker, starts Qdrant container.

{: .tip }
> After this step, you can SSH into the VM: `ssh azureuser@<VM_PUBLIC_IP>`

### Step 7 — Document Intelligence

```bash
bash modules/doc-intelligence.sh
```

This step:
1. Creates an Azure `FormRecognizer` resource with commitment tier pricing (DC0)
2. SSHs into the Qdrant VM
3. Pulls the Doc Intel container image
4. Downloads a license file (one-time connected operation)
5. Starts the container in disconnected mode on port 5050

{: .warning }
> This step requires the Qdrant VM (step 6) to be running and SSH-accessible.

### Step 8 — GPU VM

```bash
bash modules/vm-gpu.sh
```

Provisions the GPU VM, installs NVIDIA driver via VM extension, pulls and starts vLLM.

{: .note }
> The NVIDIA driver extension takes 5–10 minutes to install. The script waits for it to complete before starting vLLM.

### Step 9 — Container Apps

```bash
bash modules/container-app-env.sh
bash modules/container-app-backend.sh
bash modules/container-app-frontend.sh
```

Creates Container Apps environment and deploys backend + frontend apps with scale-to-zero.

### Step 10 — RBAC

```bash
bash modules/identity-roles.sh
```

Assigns all managed identity roles (Cognitive Services User, AcrPull, etc.).

---

## 3.4 Verify Deployment

After `deploy.sh` completes:

```bash
# List all resources
az resource list --resource-group project-lab-dev --output table

# Check VM status
az vm list --resource-group project-lab-dev \
  --query "[].{Name:name, Status:powerState}" --output table

# Get frontend URL
az containerapp show \
  --resource-group project-lab-dev \
  --name chatbot-dev-frontend \
  --query properties.configuration.ingress.fqdn --output tsv
```

---

## 3.5 Estimated Cost

| Resource | SKU | ~Monthly Cost (USD) |
|---|---|---|
| GPU VM | `Standard_NV36ads_A10_v5` | ~$1,800 (when running) |
| Qdrant VM | `Standard_D8s_v5` | ~$280 |
| AI Foundry | S0 | ~$10–50 (usage-based) |
| Doc Intelligence | DC0 (commitment) | ~$20–100 |
| Container Apps | Consumption | ~$5–20 |
| Others (ACR, KV, VNet) | — | ~$10 |

{: .warning }
> **Deallocate VMs when not in use** to avoid charges:
> ```bash
> az vm deallocate -g project-lab-dev -n chatbot-dev-gpu --no-wait
> az vm deallocate -g project-lab-dev -n chatbot-dev-vm --no-wait
> ```

[← Architecture]({{ site.baseurl }}{% link modules/02-architecture.md %}){: .btn .mr-2 }
[Next: Qdrant VM & Doc Intelligence →]({{ site.baseurl }}{% link modules/04-qdrant-doc-intelligence.md %}){: .btn .btn-primary }
