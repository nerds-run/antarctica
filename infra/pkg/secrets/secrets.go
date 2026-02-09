// Package secrets defines the 1Password items that must exist for Antarctica.
//
// There is no official Pulumi provider for 1Password. This package provides:
//   1. A declarative manifest of every secret item required.
//   2. A helper that shells out to the `op` CLI to create items.
//   3. Pulumi secret outputs so sensitive values never appear in plaintext state.
//
// Usage:
//   During `pulumi up`, the program checks whether each 1Password item exists.
//   If the `op` CLI is authenticated (OP_SERVICE_ACCOUNT_TOKEN or desktop app),
//   missing items are created automatically. Otherwise, the program logs
//   instructions for manual creation and continues without error.
package secrets

import (
	"encoding/json"
	"fmt"
	"os/exec"

	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

// Item describes a single 1Password item to provision.
type Item struct {
	// Human-readable title in 1Password.
	Title string
	// 1Password vault name.
	Vault string
	// Category (e.g. "Secure Note", "Password", "Login").
	Category string
	// Fields maps field labels to descriptions of what they hold.
	// Actual secret values are never stored in Pulumi state.
	Fields map[string]string
}

// Manifest returns the complete list of secrets required by Antarctica.
// Field values describe the expected content; actual values must be supplied
// when creating items (interactively or via CI).
func Manifest() []Item {
	return []Item{
		// Static secrets in Infrastructure vault (read-only).
		{
			Title:    "antiarctica_postgresql",
			Vault:    "Infrastructure",
			Category: "Password",
			Fields: map[string]string{
				"password": "PostgreSQL superuser password for the woodpecker database",
			},
		},
		{
			Title:    "antiarctica_woodpecker",
			Vault:    "Infrastructure",
			Category: "Secure Note",
			Fields: map[string]string{
				"agent-secret": "Shared secret between Woodpecker server and agents",
				"gitea-client": "OAuth2 client ID for Forgejo integration",
				"gitea-secret": "OAuth2 client secret for Forgejo integration",
			},
		},
		{
			Title:    "antiarctica_forgejo",
			Vault:    "Infrastructure",
			Category: "Secure Note",
			Fields: map[string]string{
				"secret-key":         "Forgejo internal secret key",
				"internal-token":     "Forgejo internal API token",
				"oauth2-jwt-secret":  "OAuth2 JWT signing secret",
				"lfs-jwt-secret":     "LFS JWT signing secret",
				"action-runner-token": "Gitea Actions runner registration token",
			},
		},
	}
}

// EnsureItems checks for each manifest item in 1Password and logs whether
// it exists. Items are NOT created automatically to avoid storing generated
// secrets in Pulumi state. Instead, missing items are reported with `op`
// commands the operator can run manually.
func EnsureItems(ctx *pulumi.Context) error {
	if !opCLIAvailable() {
		ctx.Log.Warn("1Password CLI (op) not found in PATH. "+
			"Skipping secret verification. Ensure items exist manually.", nil)
		return nil
	}

	for _, item := range Manifest() {
		exists, err := itemExists(item.Vault, item.Title)
		if err != nil {
			ctx.Log.Warn(fmt.Sprintf("Could not check 1Password item %q: %v", item.Title, err), nil)
			continue
		}

		if exists {
			ctx.Log.Info(fmt.Sprintf("1Password item %q exists in vault %q", item.Title, item.Vault), nil)
		} else {
			ctx.Log.Warn(fmt.Sprintf(
				"1Password item %q NOT found in vault %q. Create it with:\n  %s",
				item.Title, item.Vault, createCommand(item),
			), nil)
		}
	}

	// Export the manifest as a secret output so Ansible can cross-reference.
	manifestJSON, err := json.Marshal(Manifest())
	if err != nil {
		return fmt.Errorf("marshalling secrets manifest: %w", err)
	}
	ctx.Export("secrets_manifest", pulumi.ToSecret(pulumi.String(string(manifestJSON))))

	return nil
}

// opCLIAvailable returns true if the `op` binary is on PATH.
func opCLIAvailable() bool {
	_, err := exec.LookPath("op")
	return err == nil
}

// itemExists checks whether a 1Password item with the given title exists
// in the specified vault.
func itemExists(vault, title string) (bool, error) {
	cmd := exec.Command("op", "item", "get", title, "--vault", vault, "--format", "json")
	if err := cmd.Run(); err != nil {
		// Exit code 1 means "not found", which is not an error for us.
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 1 {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

// createCommand builds the `op item create` shell command for a given item.
// The operator pastes this into a terminal with OP_SESSION active.
func createCommand(item Item) string {
	cmd := fmt.Sprintf("op item create --category %q --title %q --vault %q",
		item.Category, item.Title, item.Vault)
	for label := range item.Fields {
		cmd += fmt.Sprintf(" '%s[password]='", label)
	}
	return cmd
}
