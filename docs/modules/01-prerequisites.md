---
layout: default
title: "1. Prerequisites"
nav_order: 3
parent: null
---

# Module 1 — Prerequisites
{: .no_toc }

Set up your local environment and verify Azure access before deploying infrastructure.
{: .fs-6 .fw-300 }

<details open markdown="block">
  <summary>Table of contents</summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

## 1.1 Azure Subscription

You need an Azure subscription with:

- **Contributor** role on a resource group (or ability to create one)
- **GPU quota** for `Standard_NV36ads_A10_v5` in `indonesiacentral`
- Ability to create Cognitive Services resources (AI Foundry, Document Intelligence)

{: .warning }
> GPU quota is not enabled by default. Request quota increase for `Standard_NV36ads_A10_v5` in `indonesiacentral` via the Azure portal → **Quotas** blade. This can take 1–3 business days.

### Verify GPU quota

```bash
az vm list-skus --location indonesiacentral \
  --size Standard_NV36ads_A10_v5 \
  --query "[].{Name:name, Restrictions:restrictions}" \
  --output table
```

If the output shows **no restrictions**, you're good to proceed.

---

## 1.2 Required Tools

| Tool | Minimum Version | Install |
|---|---|---|
| Azure CLI | 2.60+ | [Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Bash shell | 4.0+ | WSL2 (Windows), native (Linux/macOS) |
| Python | 3.11+ | [python.org](https://www.python.org/downloads/) |
| Docker | 24+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| SSH key pair | — | `ssh-keygen -t rsa -b 4096` |
| Git | 2.30+ | [git-scm.com](https://git-scm.com/) |

### Verify all tools

```bash
az version --output table
python3 --version
docker --version
ssh -V
git --version
```

---

## 1.3 Azure CLI Login

```bash
# Login
az login

# Set subscription (if you have multiple)
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# Verify
az account show --query "{name:name, id:id, state:state}" --output table
```

---

## 1.4 Clone the Repository

```bash
git clone https://github.com/pfrederiks/Chatbot-AzureInfra.git
cd Chatbot-AzureInfra
```

---

## 1.5 Generate SSH Key (if needed)

The deployment scripts use SSH to configure VMs. If you don't have a key pair:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

{: .note }
> The default key path `~/.ssh/id_rsa` is used by the VM provisioning scripts. If your key is at a different path, update the `vm.sh` and `vm-gpu.sh` scripts accordingly.

---

## 1.6 Review Environment Parameters

Open `infra/params/dev.env` and review the configuration:

```bash
cat infra/params/dev.env
```

Key parameters:

| Parameter | Default | Description |
|---|---|---|
| `PROJECT` | `chatbot` | Resource naming prefix |
| `ENV_NAME` | `dev` | Environment name |
| `LOCATION` | `indonesiacentral` | Azure region |
| `VM_SIZE` | `Standard_D8s_v5` | Qdrant VM SKU |
| `VM_GPU_SIZE` | `Standard_NV36ads_A10_v5` | GPU VM SKU |
| `VLLM_MODEL` | `Qwen/Qwen3.5-9B` | LLM model |

{: .tip }
> You can create a `prod.env` file with different values for a production deployment. Just run `ENV_NAME=prod bash deploy.sh`.

---

## Checklist

Before proceeding to Module 2:

- [ ] Azure CLI logged in and subscription selected
- [ ] GPU quota confirmed for `indonesiacentral`
- [ ] Python 3.11+ installed
- [ ] Docker running
- [ ] SSH key pair exists at `~/.ssh/id_rsa`
- [ ] Repository cloned
- [ ] `dev.env` reviewed

[Next: Architecture →]({% link modules/02-architecture.md %}){: .btn .btn-primary }
