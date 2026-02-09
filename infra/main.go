// Antarctica Pulumi entrypoint.
//
// This program provisions a single Proxmox VM and exports connection details
// for Ansible to consume. It does NOT install software or configure services
// on the VM -- that is Ansible's responsibility.
//
// Stack outputs consumed by Ansible:
//
//	vm_ip          - IPv4 address of the VM
//	vm_hostname    - Hostname
//	ssh_user       - Cloud-init user
//	ssh_port       - SSH port (always 22)
//	data_disk_gb   - Size of the /data disk
//	data_paths     - Expected /data subdirectories
//	firewall_ports - TCP ports to open
package main

import (
	"strconv"

	"github.com/nerdsrun/antarctica/infra/pkg/dns"
	"github.com/nerdsrun/antarctica/infra/pkg/network"
	"github.com/nerdsrun/antarctica/infra/pkg/secrets"
	"github.com/nerdsrun/antarctica/infra/pkg/storage"
	"github.com/nerdsrun/antarctica/infra/pkg/vm"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		cfg := config.New(ctx, "antarctica")

		// Read all config values with sensible defaults.
		node := cfg.Require("proxmox_node")
		hostname := cfg.Get("hostname")
		if hostname == "" {
			hostname = "antarctica"
		}

		vmID := intConfig(cfg, "vm_id", 200)
		cpuCores := intConfig(cfg, "cpu_cores", 4)
		memoryMB := intConfig(cfg, "memory_mb", 8192)
		bootDiskGB := intConfig(cfg, "boot_disk_gb", 50)
		dataDiskGB := intConfig(cfg, "data_disk_gb", 100)

		cloudInitTemplate := cfg.Get("cloud_init_template")
		if cloudInitTemplate == "" {
			cloudInitTemplate = "debian-12-cloudinit"
		}

		storagePool := cfg.Get("storage_pool")
		if storagePool == "" {
			storagePool = "local-lvm"
		}

		networkBridge := cfg.Get("network_bridge")
		if networkBridge == "" {
			networkBridge = "vmbr0"
		}

		ipAddress := cfg.Get("ip_address")
		gateway := cfg.Get("gateway")
		nameserver := cfg.Get("nameserver")
		sshUser := cfg.Get("ssh_user")
		if sshUser == "" {
			sshUser = "antarctica"
		}

		sshPort := intConfig(cfg, "ssh_port", 22)
		sshPublicKeys := cfg.Get("ssh_public_keys")

		// --- Provision the VM ---
		vmResult, err := vm.Provision(ctx, vm.Config{
			Node:              node,
			VMID:              vmID,
			Hostname:          hostname,
			CPUCores:          cpuCores,
			MemoryMB:          memoryMB,
			BootDiskGB:        bootDiskGB,
			DataDiskGB:        dataDiskGB,
			CloudInitTemplate: cloudInitTemplate,
			StoragePool:       storagePool,
			NetworkBridge:     networkBridge,
			IPAddress:         ipAddress,
			Gateway:           gateway,
			Nameserver:        nameserver,
			SSHPublicKeys:     sshPublicKeys,
			SSHUser:           sshUser,
		})
		if err != nil {
			return err
		}

		// --- Export connection details for Ansible ---
		ctx.Export("vm_ip", vmResult.IPAddress)
		ctx.Export("vm_hostname", pulumi.String(hostname))
		ctx.Export("ssh_user", pulumi.String(sshUser))
		ctx.Export("ssh_port", pulumi.Int(sshPort))

		// --- Export network details ---
		network.Export(ctx, network.Config{
			IPAddress: vmResult.IPAddress,
			Hostname:  hostname,
			Bridge:    networkBridge,
			Gateway:   gateway,
		})

		// --- Export storage layout ---
		storage.ExportDataLayout(ctx, dataDiskGB)

		// --- Create DNS records in GCP Cloud DNS ---
		gcpDNSZone := cfg.Get("gcp_dns_zone")
		dnsDomain := cfg.Get("dns_domain")
		if gcpDNSZone != "" && dnsDomain != "" {
			if err := dns.CreateRecords(ctx, dns.Config{
				ManagedZone: gcpDNSZone,
				Domain:      dnsDomain,
				IPAddress:   vmResult.IPAddress,
			}); err != nil {
				return err
			}
		}

		// --- Verify 1Password secrets ---
		if err := secrets.EnsureItems(ctx); err != nil {
			return err
		}

		return nil
	})
}

// intConfig reads an integer config value with a default fallback.
func intConfig(cfg *config.Config, key string, defaultVal int) int {
	raw := cfg.Get(key)
	if raw == "" {
		return defaultVal
	}
	val, err := strconv.Atoi(raw)
	if err != nil {
		return defaultVal
	}
	return val
}
