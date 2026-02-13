// Package network exports VM networking details as stack outputs for Ansible.
//
// Proxmox-level networking (bridge, VLAN, static IP) is configured in the VM
// module via cloud-init. This package exposes the resolved values so downstream
// tooling (Ansible dynamic inventory, CI scripts) can consume them.
//
// Firewall rules are NOT managed here. The NixOS config had the firewall
// force-disabled, and the migration strategy is:
//   - Proxmox firewall at the hypervisor level (optional, manual)
//   - Host-level ufw/nftables configured by Ansible
package network

import (
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

// Config holds network-related values to export.
type Config struct {
	// Resolved VM IP address (from QEMU guest agent).
	IPAddress pulumi.StringOutput
	// Hostname assigned to the VM.
	Hostname string
	// Network bridge the VM is attached to.
	Bridge string
	// Gateway address (empty if DHCP).
	Gateway string
}

// FirewallPorts lists the TCP ports that should be opened for Antarctica.
// Ansible uses these to configure ufw/nftables on the host.
var FirewallPorts = []int{
	22,   // OpenSSH
	80,   // Caddy HTTP
	443,  // Caddy HTTPS
	2222, // Forgejo Git SSH
	5000, // Docker Registry
	9090, // Cockpit
}

// Export registers network details as Pulumi stack outputs.
func Export(ctx *pulumi.Context, cfg Config) {
	ctx.Export("vm_ip", cfg.IPAddress)
	ctx.Export("vm_hostname", pulumi.String(cfg.Hostname))
	ctx.Export("network_bridge", pulumi.String(cfg.Bridge))
	ctx.Export("network_gateway", pulumi.String(cfg.Gateway))

	// Export the firewall port list for Ansible to consume.
	ports := make(pulumi.IntArray, len(FirewallPorts))
	for i, p := range FirewallPorts {
		ports[i] = pulumi.Int(p)
	}
	ctx.Export("firewall_ports", ports)
}
