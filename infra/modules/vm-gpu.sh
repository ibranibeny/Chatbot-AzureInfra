#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Checking GPU SKU availability: ${VM_GPU_SIZE} in ${LOCATION}"

# REQUIRED: Always check GPU availability first
SKU_INFO=$(az vm list-skus \
  --location "$LOCATION" \
  --size "$VM_GPU_SIZE" \
  --query "[].{Name:name, Restrictions:restrictions[?type=='Location'].values[0].name}" \
  --output json)

if [[ "$SKU_INFO" == "[]" ]]; then
  echo "!!! ERROR: ${VM_GPU_SIZE} is NOT available in ${LOCATION}"
  echo "!!! Check nearest regions: southeastasia, australiaeast"
  echo "!!! Run: az vm list-skus --location southeastasia --size ${VM_GPU_SIZE} --output table"
  exit 1
fi

echo ">>> GPU SKU ${VM_GPU_SIZE} available — proceeding"

# Cloud-init for Docker + NVIDIA Container Toolkit + vLLM
# NOTE: NVIDIA GPU driver is installed via the Azure VM extension (below), not cloud-init.
CLOUD_INIT=$(cat <<'CLOUD_INIT_EOF'
#!/bin/bash
set -euo pipefail

# Install Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker azureuser

# Install NVIDIA Container Toolkit
# (Requires NVIDIA driver to be installed first — handled by VM extension)
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L "https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list" \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# Create model cache directory
mkdir -p /data/models
chown azureuser:azureuser /data/models

# Create a systemd service that starts vLLM after reboot (driver extension may reboot the VM)
cat > /etc/systemd/system/vllm.service <<'SVC'
[Unit]
Description=vLLM Qwen3.5-9B
After=docker.service
Requires=docker.service

[Service]
Restart=on-failure
RestartSec=30
ExecStartPre=-/usr/bin/docker rm -f vllm-qwen
ExecStart=/usr/bin/docker run --gpus all \
  --name vllm-qwen \
  -p 8000:8000 \
  -v /data/models:/root/.cache/huggingface \
  vllm/vllm-openai:latest \
  --model Qwen/Qwen3.5-9B \
  --host 0.0.0.0 \
  --port 8000 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.9
ExecStop=/usr/bin/docker stop vllm-qwen

[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload
systemctl enable vllm.service
CLOUD_INIT_EOF
)

echo ">>> Creating GPU VM: ${VM_GPU_NAME} (${VM_GPU_SIZE})"

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_GPU_NAME" \
  --location "$LOCATION" \
  --image "$VM_IMAGE" \
  --size "$VM_GPU_SIZE" \
  --admin-username "$VM_ADMIN" \
  --generate-ssh-keys \
  --assign-identity \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_GPU" \
  --nsg "$VM_GPU_NSG" \
  --os-disk-size-gb 256 \
  --storage-sku Premium_LRS \
  --custom-data <(echo "$CLOUD_INIT") \
  --output json

# Install NVIDIA GPU driver via Azure VM extension (Microsoft.HpcCompute)
# Ref: https://learn.microsoft.com/azure/virtual-machines/extensions/hpccompute-gpu-linux
echo ">>> Installing NVIDIA GPU driver via VM extension (NvidiaGpuDriverLinux)"

az vm extension set \
  --resource-group "$RESOURCE_GROUP" \
  --vm-name "$VM_GPU_NAME" \
  --name NvidiaGpuDriverLinux \
  --publisher Microsoft.HpcCompute \
  --version 1.6 \
  --output none

echo ">>> NVIDIA driver extension installed — VM may reboot to complete setup"
echo ">>> vLLM systemd service will start automatically after driver is ready"

# Start vLLM service (if VM did not reboot)
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_GPU_NAME" \
  --command-id RunShellScript \
  --scripts "systemctl start vllm.service || true" \
  --output none 2>/dev/null || true

echo ">>> GPU VM ${VM_GPU_NAME} created with NVIDIA driver extension + vLLM"
echo ">>> Endpoint will be available at http://<VM_IP>:${VLLM_PORT}/v1/chat/completions"
