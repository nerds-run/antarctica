#!/usr/bin/env python3
"""Dynamic Ansible inventory from Pulumi stack outputs."""
import json
import os
import sys


def main():
    output_file = os.path.join(os.path.dirname(__file__), "pulumi_output.json")

    if not os.path.exists(output_file):
        # Return empty inventory if no Pulumi output exists
        print(json.dumps({"_meta": {"hostvars": {}}}))
        return

    with open(output_file) as f:
        pulumi_output = json.load(f)

    vm_ip = pulumi_output.get("vm_ip", "")
    vm_hostname = pulumi_output.get("vm_hostname", "antarctica")

    inventory = {
        "antarctica": {
            "hosts": [vm_hostname],
        },
        "_meta": {
            "hostvars": {
                vm_hostname: {
                    "ansible_host": vm_ip,
                    "ansible_user": "deploy",
                    "ansible_ssh_private_key_file": "~/.ssh/antarctica_ed25519",
                    "ansible_python_interpreter": "/usr/bin/python3",
                }
            }
        },
    }

    print(json.dumps(inventory, indent=2))


if __name__ == "__main__":
    main()
