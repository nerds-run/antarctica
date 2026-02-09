// Package storage documents the disk layout provisioned by the VM module.
//
// Pulumi creates the raw disks (boot + data) as part of VM provisioning.
// Ansible is responsible for partitioning, formatting, and mounting:
//
//	scsi0 (boot disk)  -> / (ext4, managed by cloud-init)
//	scsi1 (data disk)  -> /data (ext4, formatted + mounted by Ansible)
//
// The /data mount holds all persistent service data:
//
//	/data/containers     -> Podman container storage
//	/data/forgejo        -> Forgejo repositories + data
//	/data/woodpecker     -> Woodpecker server state
//	/data/registry       -> Docker registry layers
//	/data/postgresql     -> PostgreSQL data directory
//	/data/libvirt        -> Libvirt VM storage
//	/data/docker         -> Docker data root
package storage

import (
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

// DataPaths enumerates the directories Ansible should create under /data.
// Exported as a stack output so the Ansible inventory can reference them.
var DataPaths = []string{
	"/data/containers",
	"/data/forgejo",
	"/data/woodpecker",
	"/data/registry",
	"/data/postgresql",
	"/data/libvirt",
	"/data/docker",
}

// ExportDataLayout registers the expected /data subdirectories as a stack
// output. Ansible reads these to create mount points and bind mounts.
func ExportDataLayout(ctx *pulumi.Context, dataDiskGB int) {
	ctx.Export("data_disk_gb", pulumi.Int(dataDiskGB))
	ctx.Export("data_paths", pulumi.ToStringArray(DataPaths))
}
