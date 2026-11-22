package main

import rego.v1

workload_kinds := {"Deployment", "StatefulSet", "DaemonSet"}

# Internal chart-rendered config secrets that contain routing/scrape/app configs rather than credentials
allowed_config_secrets := {
	"alertmanager-monitoring-kube-prometheus-alertmanager",
	"monitoring-kube-prometheus-prometheus-scrape-confg",
	"authentik",
}

# Deny plaintext Secrets containing data (enforce ExternalSecrets Operator)
deny contains msg if {
	input.kind == "Secret"
	not input.type == "kubernetes.io/tls"
	not input.type == "helm.sh/release.v1"
	not input.metadata.annotations["helm.sh/hook"]
	not is_empty_secret(input)
	not allowed_config_secrets[input.metadata.name]
	msg := sprintf("Plaintext Secret '%s' is forbidden. Use an ExternalSecret resource instead.", [input.metadata.name])
}

# Allow empty placeholder secrets populated at runtime by admission webhook controllers or upstream charts
is_empty_secret(secret) if {
	all_empty_values(object.get(secret, "data", {}))
	all_empty_values(object.get(secret, "stringData", {}))
}

all_empty_values(obj) if {
	every _, v in obj {
		v == ""
	}
}

# Deny containers using :latest or omitting an explicit tag
deny contains msg if {
	workload_kinds[input.kind]
	some container in input.spec.template.spec.containers
	has_mutable_tag(container.image)
	msg := sprintf("%s '%s' uses a mutable or missing tag on image '%s'. Pin a version tag or SHA.", [input.kind, input.metadata.name, container.image])
}

has_mutable_tag(image) if {
	endswith(image, ":latest")
}

has_mutable_tag(image) if {
	not contains(image, ":")
	not contains(image, "@sha256:")
}
