// Package dns creates GCP Cloud DNS records for Antarctica services.
//
// DNS records are created in the dev.nerds.run private zone, pointing
// service subdomains (forgejo, woodpecker, etc.) to the VM's IP address.
// GCP credentials come from the Pulumi ESC environment dev-nerds-run/gcp.
package dns

import (
	"fmt"

	"github.com/pulumi/pulumi-gcp/sdk/v8/go/gcp/dns"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

// Config holds the parameters for DNS record creation.
type Config struct {
	// GCP managed zone name (e.g. "dev-nerds-run")
	ManagedZone string
	// Base domain (e.g. "dev.nerds.run")
	Domain string
	// VM IP address (Pulumi output from VM provisioning)
	IPAddress pulumi.StringOutput
}

// Record describes a single DNS A record to create.
type Record struct {
	// Subdomain prefix (e.g. "forgejo" creates forgejo.dev.nerds.run)
	Subdomain string
}

// DefaultRecords returns the DNS records needed for Antarctica services.
func DefaultRecords() []Record {
	return []Record{
		{Subdomain: "forgejo"},
		{Subdomain: "woodpecker"},
		{Subdomain: "sshx"},
		{Subdomain: "registry"},
		{Subdomain: "vscode"},
		{Subdomain: "cockpit"},
	}
}

// CreateRecords creates DNS A records in GCP Cloud DNS for each service.
func CreateRecords(ctx *pulumi.Context, cfg Config) error {
	records := DefaultRecords()

	for _, rec := range records {
		fqdn := fmt.Sprintf("%s.%s.", rec.Subdomain, cfg.Domain)
		resourceName := fmt.Sprintf("dns-%s", rec.Subdomain)

		_, err := dns.NewRecordSet(ctx, resourceName, &dns.RecordSetArgs{
			ManagedZone: pulumi.String(cfg.ManagedZone),
			Name:        pulumi.String(fqdn),
			Type:        pulumi.String("A"),
			Ttl:         pulumi.Int(300),
			Rrdatas:     pulumi.StringArray{cfg.IPAddress},
		})
		if err != nil {
			return fmt.Errorf("creating DNS record for %s: %w", fqdn, err)
		}

		ctx.Log.Info(fmt.Sprintf("DNS record: %s -> VM IP", fqdn), nil)
	}

	return nil
}
