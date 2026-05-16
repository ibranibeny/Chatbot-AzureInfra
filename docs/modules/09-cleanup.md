---
layout: default
title: "9. Cleanup"
nav_order: 11
---

# Module 9 — Cleanup
{: .no_toc }

Destroy all Azure resources to stop incurring charges.
{: .fs-6 .fw-300 }

---

## Option A — Fast Cleanup (Recommended)

Delete the entire resource group at once:

```bash
cd infra
ENV_NAME=dev bash destroy.sh --fast
```

This removes **everything** in `project-lab-dev` with a single `az group delete` command.

{: .warning }
> This is irreversible. All data (Qdrant vectors, Doc Intelligence license, Key Vault secrets) will be permanently deleted.

---

## Option B — Gradual Cleanup

Delete resources individually in reverse order (useful for keeping some resources):

```bash
cd infra
ENV_NAME=dev bash destroy.sh
```

This runs 10 steps:

| Step | Action | Script |
|---|---|---|
| 1 | Remove RBAC assignments | `identity-roles-delete.sh` |
| 2 | Delete Frontend Container App | `container-app-frontend-delete.sh` |
| 3 | Delete Backend Container App | `container-app-backend-delete.sh` |
| 4 | Delete Container Apps Environment | `container-app-env-delete.sh` |
| 5 | Delete GPU VM | `vm-gpu-delete.sh` |
| 6 | Delete Doc Intelligence cloud resource | `doc-intelligence-delete.sh` |
| 7 | Delete Qdrant VM | `vm-delete.sh` |
| 8 | Delete AI Foundry | `ai-foundry-delete.sh` |
| 9 | Delete Key Vault | `keyvault-delete.sh` |
| 10 | Delete ACR + VNet + Resource Group | `acr-delete.sh`, `vnet-delete.sh`, `resource-group-delete.sh` |

---

## Save Money Without Destroying

If you want to keep resources but stop charges:

### Deallocate VMs (saves ~$2,100/month)

```bash
# Stop GPU VM (biggest cost)
az vm deallocate -g project-lab-dev -n chatbot-dev-gpu --no-wait

# Stop Qdrant VM
az vm deallocate -g project-lab-dev -n chatbot-dev-vm --no-wait
```

### Scale Container Apps to zero

Container Apps already scale to zero when idle — no action needed.

### Restart when ready

```bash
az vm start -g project-lab-dev -n chatbot-dev-vm --no-wait
az vm start -g project-lab-dev -n chatbot-dev-gpu --no-wait
```

{: .tip }
> After restarting VMs, Docker containers with `--restart unless-stopped` will auto-start (Qdrant, vLLM).

---

## Verify Cleanup

```bash
# Check resource group is gone
az group exists --name project-lab-dev
# Expected: false

# Or list remaining resources
az resource list -g project-lab-dev -o table 2>/dev/null || echo "Resource group deleted"
```

---

## Workshop Complete! 🎉

You've successfully built a complete RAG chatbot system on Azure with:

- ✅ Self-hosted LLM (Qwen3.5-9B) on GPU VM
- ✅ Vector search with Qdrant
- ✅ Cloud document processing with Azure Document Intelligence
- ✅ Embeddings via Azure AI Foundry
- ✅ Scalable serving with Container Apps
- ✅ Infrastructure as Code with Azure CLI

### Next Steps

- **Production hardening**: Add authentication, monitoring, rate limiting
- **Scale up**: Use Azure AI Search instead of Qdrant, add load balancing
- **Multi-model**: Deploy multiple LLMs behind a router
- **CI/CD**: Add GitHub Actions for automated deployment
- **Observability**: Integrate Application Insights and Azure Monitor

[← Testing & Troubleshooting]({{ site.baseurl }}{% link modules/08-testing.md %}){: .btn .mr-2 }
[Back to Home →]({{ site.baseurl }}{% link index.md %}){: .btn .btn-primary }
