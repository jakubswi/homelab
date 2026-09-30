.RECIPEPREFIX := >
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help
# Always target the homelab cluster, never whatever KUBECONFIG your shell has.
export KUBECONFIG := $(CURDIR)/.kubeconfig.yaml

.PHONY: help configure ansible-deps provision provision-check deps lint validate bootstrap argocd-password argocd-ui backup-sealing-key

help: ## Show this help
> @grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-20s %s\n", $$1, $$2}'

configure: ## Set placeholders: make configure DOMAIN=mydomain.tld GITHUB_USER=me [LAN=192.168.1]
> @bash scripts/configure.sh "$(DOMAIN)" "$(GITHUB_USER)" "$(LAN)"

ansible-deps: ## Install required Ansible collections
> cd ansible && ansible-galaxy collection install -r requirements.yml

provision: ## Harden the host and install k3s
> cd ansible && ansible-playbook site.yml -K

provision-check: ## Dry-run the playbook
> cd ansible && ansible-playbook site.yml --check --diff -K

deps: ## Refresh Helm dependencies and Chart.lock files
> bash scripts/helm-deps.sh

lint: ## yamllint + ansible-lint
> yamllint .
> cd ansible && ansible-lint

validate: ## Render every chart/kustomization and validate with kubeconform
> bash scripts/validate.sh

bootstrap: ## Install Argo CD and apply the root app (one time)
> bash bootstrap/bootstrap.sh

argocd-password: ## Print the initial Argo CD admin password
> @kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

argocd-ui: ## Port-forward Argo CD to http://localhost:8080
> kubectl -n argocd port-forward svc/argocd-server 8080:80

backup-sealing-key: ## Export the Sealed Secrets key (store OFFLINE, never in git)
> kubectl -n sealed-secrets get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key.backup.yaml
> @echo "Wrote sealed-secrets-key.backup.yaml. Move it to a password manager or offline storage, then delete the local copy."
