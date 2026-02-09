#!/usr/bin/env bash
set -euo pipefail

echo "==> Antarctica Bootstrap"
echo "    This script provisions infrastructure and configures the server."
echo ""

# Check prerequisites
command -v pulumi >/dev/null 2>&1 || { echo "ERROR: pulumi not found. Install with: mise install"; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { echo "ERROR: ansible-playbook not found. Install with: pip install ansible"; exit 1; }
command -v op >/dev/null 2>&1 || { echo "ERROR: 1Password CLI (op) not found."; exit 1; }

# Check 1Password session
op account list >/dev/null 2>&1 || { echo "ERROR: Not signed into 1Password. Run: eval \$(op signin)"; exit 1; }

echo "==> Step 1: Provisioning infrastructure with Pulumi..."
cd infra
pulumi stack select dev 2>/dev/null || pulumi stack init dev
pulumi up --yes
echo ""

echo "==> Step 2: Generating Ansible inventory from Pulumi outputs..."
pulumi stack output --json > ../ansible/inventory/pulumi_output.json

VM_IP=$(pulumi stack output vm_ip 2>/dev/null || echo "")
if [ -z "$VM_IP" ]; then
    echo "WARNING: Could not get VM IP from Pulumi. Update ansible/inventory/hosts.yml manually."
else
    echo "    VM IP: $VM_IP"
    # Update hosts.yml with the actual IP
    cd ../ansible
    cat > inventory/hosts.yml << EOF
---
all:
  children:
    antarctica:
      hosts:
        antarctica-server:
          ansible_host: ${VM_IP}
          ansible_user: deploy
          ansible_ssh_private_key_file: ~/.ssh/antarctica_ed25519
          ansible_python_interpreter: /usr/bin/python3
EOF
    cd ../infra
fi
cd ..

echo ""
echo "==> Step 3: Waiting for SSH availability..."
TIMEOUT=120
ELAPSED=0
while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i ~/.ssh/antarctica_ed25519 deploy@${VM_IP:-localhost} "echo ok" >/dev/null 2>&1; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "ERROR: SSH not available after ${TIMEOUT}s. Check VM status."
        exit 1
    fi
    echo "    Waiting for SSH... (${ELAPSED}s/${TIMEOUT}s)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done
echo "    SSH is available!"

echo ""
echo "==> Step 4: Running Ansible configuration..."
cd ansible
ansible-playbook playbooks/site.yml -i inventory/
cd ..

echo ""
echo "==> Antarctica is ready!"
echo "    Forgejo:    https://forgejo.dev.nerds.run"
echo "    Woodpecker: https://woodpecker.dev.nerds.run"
echo "    Cockpit:    https://${VM_IP:-localhost}:9090"
echo ""
echo "    SSH: ssh -i ~/.ssh/antarctica_ed25519 deploy@${VM_IP:-localhost}"
