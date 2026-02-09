// Package vm provisions Proxmox virtual machines for the Antarctica server.
package vm

import (
	"fmt"

	proxmox "github.com/muhlba91/pulumi-proxmoxve/sdk/v6/go/proxmoxve/vm"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

// Config holds all tunables for the Proxmox VM.
type Config struct {
	// Proxmox target node (e.g. "pve").
	Node string
	// Numeric VM ID on the Proxmox cluster.
	VMID int
	// Hostname written into cloud-init.
	Hostname string
	// Number of CPU cores.
	CPUCores int
	// Memory in megabytes.
	MemoryMB int
	// Boot disk size in gigabytes.
	BootDiskGB int
	// Data disk size in gigabytes (mounted at /data by Ansible).
	DataDiskGB int
	// Name of the cloud-init template to clone (must exist on Node).
	CloudInitTemplate string
	// Proxmox storage pool for disks (e.g. "local-lvm").
	StoragePool string
	// Network bridge (e.g. "vmbr0").
	NetworkBridge string
	// Static IP in CIDR notation (e.g. "10.0.0.50/24"). Empty string means DHCP.
	IPAddress string
	// Gateway for static IP configuration.
	Gateway string
	// DNS nameserver.
	Nameserver string
	// SSH public keys injected via cloud-init (newline-separated).
	SSHPublicKeys string
	// Default SSH user created by cloud-init.
	SSHUser string
}

// Result contains the outputs produced after VM creation.
type Result struct {
	// The Proxmox VM resource.
	VM *proxmox.VirtualMachine
	// Resolved IPv4 address of the VM.
	IPAddress pulumi.StringOutput
}

// Provision creates a Proxmox VM by cloning a cloud-init template.
func Provision(ctx *pulumi.Context, cfg Config) (*Result, error) {
	// Determine cloud-init IP config: static or DHCP.
	useDHCP := cfg.IPAddress == ""

	// Build the DNS servers list for cloud-init (empty if using DHCP).
	var dnsServers pulumi.StringArray
	if cfg.Nameserver != "" {
		dnsServers = pulumi.StringArray{pulumi.String(cfg.Nameserver)}
	}

	vm, err := proxmox.NewVirtualMachine(ctx, cfg.Hostname, &proxmox.VirtualMachineArgs{
		NodeName: pulumi.String(cfg.Node),
		VmId:     pulumi.Int(cfg.VMID),
		Name:     pulumi.String(cfg.Hostname),

		// Baseline: UEFI firmware + q35 machine type (modern PCIe).
		Bios:    pulumi.String("ovmf"),
		Machine: pulumi.String("q35"),

		// Clone from an existing cloud-init template.
		Clone: &proxmox.VirtualMachineCloneArgs{
			NodeName: pulumi.String(cfg.Node),
			VmId:     pulumi.Int(cfg.VMID),
			Full:     pulumi.Bool(true),
		},

		// Baseline: CPU type "host" for best performance + instruction sets.
		Cpu: &proxmox.VirtualMachineCpuArgs{
			Cores:   pulumi.Int(cfg.CPUCores),
			Sockets: pulumi.Int(1),
			Type:    pulumi.String("host"),
		},

		// Baseline: Dedicated memory, ballooning disabled.
		Memory: &proxmox.VirtualMachineMemoryArgs{
			Dedicated: pulumi.Int(cfg.MemoryMB),
			Floating:  pulumi.Int(0),
		},

		// Enable QEMU guest agent for Proxmox integration.
		Agent: &proxmox.VirtualMachineAgentArgs{
			Enabled: pulumi.Bool(true),
			Trim:    pulumi.Bool(true),
			Type:    pulumi.String("virtio"),
		},

		// Baseline: VirtIO SCSI controller (NOT "Single").
		ScsiHardware: pulumi.String("virtio-scsi-pci"),

		// Boot disk (root filesystem) + data disk.
		// Baseline: raw format, write-through cache, SSD emulation + discard.
		Disks: proxmox.VirtualMachineDiskArray{
			// Boot disk: OS root filesystem.
			&proxmox.VirtualMachineDiskArgs{
				Interface:   pulumi.String("scsi0"),
				Size:        pulumi.Int(cfg.BootDiskGB),
				DatastoreId: pulumi.String(cfg.StoragePool),
				FileFormat:  pulumi.String("raw"),
				Cache:       pulumi.String("writethrough"),
				Ssd:         pulumi.Bool(true),
				Discard:     pulumi.String("on"),
			},
			// Data disk: persistent service data (/data), attached by Ansible.
			&proxmox.VirtualMachineDiskArgs{
				Interface:   pulumi.String("scsi1"),
				Size:        pulumi.Int(cfg.DataDiskGB),
				DatastoreId: pulumi.String(cfg.StoragePool),
				FileFormat:  pulumi.String("raw"),
				Cache:       pulumi.String("writethrough"),
				Ssd:         pulumi.Bool(true),
				Discard:     pulumi.String("on"),
			},
		},

		// EFI disk required for UEFI/OVMF firmware.
		EfiDisk: &proxmox.VirtualMachineEfiDiskArgs{
			DatastoreId:    pulumi.String(cfg.StoragePool),
			PreEnrolledKeys: pulumi.Bool(false),
			Type:           pulumi.String("4m"),
		},

		// Baseline: virtio network model for best performance.
		NetworkDevices: proxmox.VirtualMachineNetworkDeviceArray{
			&proxmox.VirtualMachineNetworkDeviceArgs{
				Bridge: pulumi.String(cfg.NetworkBridge),
				Model:  pulumi.String("virtio"),
			},
		},

		// Cloud-init configuration.
		Initialization: &proxmox.VirtualMachineInitializationArgs{
			Type: pulumi.String("nocloud"),
			Dns: &proxmox.VirtualMachineInitializationDnsArgs{
				Domain:  pulumi.String("dev.nerds.run"),
				Servers: dnsServers,
			},
			IpConfigs: proxmox.VirtualMachineInitializationIpConfigArray{
				buildIPConfig(useDHCP, cfg.IPAddress, cfg.Gateway),
			},
			UserAccount: &proxmox.VirtualMachineInitializationUserAccountArgs{
				Username: pulumi.String(cfg.SSHUser),
				Keys:     pulumi.ToStringArray(splitKeys(cfg.SSHPublicKeys)),
			},
		},

		// Boot order: disk first, then network.
		BootOrders: pulumi.StringArray{
			pulumi.String("scsi0"),
			pulumi.String("net0"),
		},

		// Start VM on creation.
		Started: pulumi.Bool(true),

		// OS type hint for Proxmox (Linux 2.6+ kernel).
		OperatingSystem: &proxmox.VirtualMachineOperatingSystemArgs{
			Type: pulumi.String("l26"),
		},
	})
	if err != nil {
		return nil, fmt.Errorf("creating proxmox VM: %w", err)
	}

	// Extract the first IPv4 address from the VM's network interfaces.
	// The QEMU guest agent reports this once the VM boots.
	ipAddr := vm.Ipv4Addresses.ApplyT(func(addrs [][]string) string {
		// addrs is indexed by interface; skip loopback (usually index 0).
		for i, iface := range addrs {
			if i == 0 {
				continue // skip loopback
			}
			if len(iface) > 0 {
				return iface[0]
			}
		}
		// Fallback: return first address of first interface.
		if len(addrs) > 0 && len(addrs[0]) > 0 {
			return addrs[0][0]
		}
		return ""
	}).(pulumi.StringOutput)

	return &Result{
		VM:        vm,
		IPAddress: ipAddr,
	}, nil
}

// buildIPConfig returns either a DHCP or static IP cloud-init config.
func buildIPConfig(dhcp bool, ipAddr, gateway string) *proxmox.VirtualMachineInitializationIpConfigArgs {
	if dhcp {
		return &proxmox.VirtualMachineInitializationIpConfigArgs{
			Ipv4: &proxmox.VirtualMachineInitializationIpConfigIpv4Args{
				Address: pulumi.String("dhcp"),
			},
		}
	}
	return &proxmox.VirtualMachineInitializationIpConfigArgs{
		Ipv4: &proxmox.VirtualMachineInitializationIpConfigIpv4Args{
			Address: pulumi.String(ipAddr),
			Gateway: pulumi.String(gateway),
		},
	}
}

// splitKeys splits a newline-separated list of SSH public keys into a slice,
// filtering out empty lines.
func splitKeys(keys string) []string {
	var result []string
	start := 0
	for i := 0; i <= len(keys); i++ {
		if i == len(keys) || keys[i] == '\n' {
			line := keys[start:i]
			if len(line) > 0 && line != "\n" {
				result = append(result, line)
			}
			start = i + 1
		}
	}
	return result
}
