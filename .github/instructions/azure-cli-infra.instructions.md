---
description: "Use when creating or modifying Azure CLI provisioning scripts in the infra/ directory. Enforces idempotency, naming, and security conventions."
applyTo: "infra/**"
---

# Azure CLI IaC Conventions

## Research First
Before writing or modifying provisioning scripts, use the Microsoft Learn MCP tools to verify best practices:
1. **`microsoft_docs_search`** — Search for the Azure service's latest CLI provisioning guidance
2. **`microsoft_code_sample_search`** — Find official `az` CLI code samples for the target resource
3. **`microsoft_docs_fetch`** — Fetch full documentation when search results are insufficient (e.g., networking, managed identity setup, security hardening)

Use these tools to ensure scripts align with current Microsoft-recommended patterns for resource configuration, SKU selection, networking, identity, and security.

## GPU VM Availability Check — REQUIRED
Before any GPU-related provisioning, **always** verify `Standard_NV36ads_A10_v5` (NVIDIA A10, 24 GB VRAM) is available in `indonesiacentral`:
```bash
az vm list-skus --location indonesiacentral --size Standard_NV36ads_A10_v5 \
  --query "[].{Name:name, Restrictions:restrictions}" --output table
```
- If the SKU shows **no restrictions** → proceed with the GPU VM in `indonesiacentral`
- If restricted or unavailable → alert the user and suggest the nearest region with availability (e.g., `southeastasia`, `australiaeast`)
- **Never** assume GPU SKU availability — always run the check first

## Qdrant Reference
When writing scripts that provision or configure Qdrant, consult:
- **Official docs**: https://qdrant.tech/documentation/
- **Quickstart (Docker)**: https://qdrant.tech/documentation/quickstart/
- **Security**: https://qdrant.tech/documentation/security/
- **Manage data (collections, payloads, indexing)**: https://qdrant.tech/documentation/manage-data/
- **Search (similarity, filtering, hybrid)**: https://qdrant.tech/documentation/search/

Key Qdrant patterns for this project:
- Deploy via Docker on VM: `docker run -p 6333:6333 -p 6334:6334 -v /data/qdrant:/qdrant/storage qdrant/qdrant`
- REST API on port **6333**, gRPC on port **6334**, Web UI at `localhost:6333/dashboard`
- Secure with API key via `QDRANT__SERVICE__API_KEY` env var
- Create collections with correct vector dimensions matching embedding model (e.g., `1536` for `text-embedding-3-small`)
- Use payload indexes for filtered search performance

## GitHub Workflow
- **Create a new GitHub repo** at the start of the project if one doesn't exist; use the GitHub MCP tools or `gh repo create`
- **Push frequently** — commit and push after every meaningful change (new script, config update, bug fix). Do not batch large changes
- Commit messages: `feat: add <resource>`, `fix: <what>`, `docs: update <file>`

## Documentation — REQUIRED
Every project must include:
- **`README.md`** — Project overview, architecture diagram, prerequisites, quick start
- **`docs/guidance.md`** — Detailed guidance on design decisions, security, networking, and identity
- **`docs/workshop/`** — Step-by-step workshop instructions, published to **GitHub Pages** (`github.io`). Use Markdown files with clear numbered steps, screenshots where helpful
- Enable GitHub Pages on the repo (`Settings → Pages → Deploy from branch: main, /docs`)

## Architecture Diagram — draw.io with Azure Shapes

### Quality Standard
- You are a **professional Solution Architect** specializing in Azure Infrastructure and AI Applications
- The diagram must look like it was created by an experienced Azure Solutions Engineer — clean, precise, and presentation-ready
- Every arrow must be **intentional and correct** — no crossing lines, no ambiguous directions, no spaghetti routing

### Arrow & Connector Rules
- **Direction matters**: arrows flow left-to-right (request path) or top-to-bottom (hierarchy). Never draw arrows that contradict the actual data flow
- **No overlapping arrows**: if two edges would overlap, use waypoints (`<Array as="points">`) to route them around other shapes
- **Bidirectional arrows** (`startArrow=classic;endArrow=classic`) ONLY when both sides initiate requests (e.g., Backend ↔ Qdrant search). Use single-direction arrows for one-way flows (User → Frontend)
- **Label placement**: edge labels must sit on the midpoint of the connector and not overlap with other labels or shapes
- **Consistent line weights**: primary data flow = `strokeWidth=2`, secondary/support = `strokeWidth=1`
- **Three line styles** — each must be visually distinct:
  1. **Data flow** — solid line, `strokeColor=#0078D4`, `strokeWidth=2`
  2. **Managed identity / RBAC** — dotted line, `strokeColor=#999`, `dashed=1;dashPattern=3 3`, `strokeWidth=1`, label = RBAC role name
  3. **Ingestion pipeline** — dashed line, `strokeColor=#E65100`, `dashed=1;dashPattern=8 4`, `strokeWidth=1`
- **Waypoints for clarity**: when edges must cross zones (e.g., VM in vm-subnet → AI Foundry outside VNet), add intermediate waypoints so the line follows a clean L-shaped or Z-shaped path instead of cutting diagonally through other shapes
- **Spacing**: maintain ≥40px gap between parallel arrows; stagger source/target connection points on shapes to avoid fan-out overlap

### Reference Guide
- https://www.drawio.com/blog/azure-diagrams — follow this for creating Azure architecture diagrams
- **Always** create and maintain a draw.io architecture diagram at `docs/architecture.drawio`
- Use the **draw.io MCP server** (`drawio-mcp-server` — https://github.com/lgazo/drawio-mcp-server) to create and update diagrams programmatically when available
- Enable the **Azure shape library** in draw.io: `More Shapes → Networking → Azure` (see guide above)

### Azure Icon Shapes
- Use **Azure icon shapes** (`img/lib/azure2/` SVG paths) — represent each Azure resource with its official icon:
  - Compute: `img/lib/azure2/compute/Virtual_Machines.svg`
  - Containers: `img/lib/azure2/containers/Container_Apps.svg`, `Container_Registries.svg`
  - AI/ML: `img/lib/azure2/ai_machine_learning/Azure_OpenAI.svg`, `Form_Recognizers.svg`
  - Networking: `img/lib/azure2/networking/Virtual_Networks.svg`, `Network_Security_Groups.svg`
  - Security: `img/lib/azure2/security/Key_Vaults.svg`
- **Icon-label separation**: place the Azure SVG icon in one cell and the resource name/details in a separate text cell below it. Never embed long text directly on an SVG shape

### Layout & Grouping
- **Region grouping**: Use rectangles with dashed outlines or coloured backgrounds to indicate Azure regions (per draw.io guide). Send region rectangles to back so they sit behind resource icons
- **Logical blocks**: Group related resources in the diagram:
  - Azure subscription (outer boundary)
  - Resource group (`project-lab-{env}`)
  - VNet with subnets (nested dashed rectangles, colour-coded per subnet)
  - Managed services (outside VNet, in a separate zone to the right)
- **Alignment**: shapes within a subnet should be left-aligned or center-aligned — never scattered randomly
- **Z-order**: background layers (region → RG → VNet → subnet) must be sent to back so icons sit on top

### Required Content
- The diagram must show:
  - All Azure resources with their SKUs and key configuration
  - Network topology (VNet, subnets, NSG rules with allowed/denied ports)
  - Data flow arrows (User → Frontend → Backend → Qdrant / vLLM) — solid lines
  - Managed identity connections — dotted lines with RBAC role labels (AcrPull, Cognitive Services OpenAI User)
  - Ingestion flow — dashed lines (Doc Intelligence → Embedding Pipeline → Qdrant)
  - Region grouping (`indonesiacentral`)
  - Legend box explaining all three line styles + subnet boundary style
- Export a PNG/SVG to `docs/architecture.png` for embedding in `README.md` and workshop docs
- Update the diagram whenever infrastructure changes

## Testing with MCP Playwright
- **Always** create end-to-end tests using MCP Playwright to validate deployments
- Test scenarios: frontend loads, API health endpoint responds, Qdrant REST API reachable, vLLM `/v1/models` returns model list
- Place test files in `tests/e2e/`
- Run tests after `deploy.sh` completes to verify the full stack

## Deployment Lifecycle — Deploy AND Delete
Every deployable resource MUST have **both** scripts:
- `modules/<resource>.sh` — Creates/updates the resource (idempotent)
- `modules/<resource>-delete.sh` — Tears down the resource cleanly
- Top-level orchestrators: `deploy.sh` (runs all create scripts) and `destroy.sh` (runs all delete scripts in reverse order)
- Delete scripts should use `az resource delete` with `--yes` flag and `--output none`
- Delete scripts must be safe to run even if the resource doesn't exist (use `|| true` or check existence first)

## Script Structure
- Each script targets **one resource type** (e.g., `create-vm.sh`, `create-container-app.sh`)
- Scripts must be **idempotent**: use `az resource show` checks before `az resource create`, or rely on `--only-show-errors` with upsert-style commands
- Begin every script with `set -euo pipefail`

## Naming & Parameters
- **Resource group** name prefix: `project-lab-` (e.g., `project-lab-dev`, `project-lab-prod`)
- Resource names follow pattern: `{project}-{env}-{resource}` (e.g., `chatbot-dev-vm`)
- Read shared parameters from environment variables or source a params file: `source ./params/dev.env`
- Required variables: `RESOURCE_GROUP`, `LOCATION`, `ENV_NAME`

## Security
- **Never** embed secrets in scripts — use `az keyvault secret set/show`
- Assign managed identity with `--assign-identity` where supported
- Restrict network access: use `--subnet`, `--vnet-name`, NSG rules

## Output
- Use `--output json` when capturing resource IDs for downstream scripts
- Use `--output none` for fire-and-forget operations
- Log progress with `echo ">>> Creating resource..."` prefixed messages
