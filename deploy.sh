#!/usr/bin/env bash
set -eo pipefail

cd "$(dirname "${0}")" || exit 1

kubectl_context="default"
namespace="app-mediacenter"
release_name="app-mediacenter"

if ! kubectl config use-context "${kubectl_context}"; then
    echo "Cannot change kubectl context to ${kubectl_context}. It may be the context does not exists."
    exit 1
fi
echo

if ! helm repo add --force-update jellyfin https://jellyfin.github.io/jellyfin-helm; then
    echo -n "Helm grafana repo add has failed. Network issues?"
    exit 1
fi

if ! helm dependency update && helm dependency build; then
    echo -n "Helm dependency update has failed. Please fix your dependencies before proceed."
    exit 1
fi

if ! helm lint --debug .; then
    echo -n "Helm linter has failed. Please fix your chart before proceed."
    exit 1
fi

echo "Upgrading release..."
if ! helm upgrade "${release_name}" . \
        --atomic \
        --cleanup-on-fail \
        --create-namespace \
        --debug \
        --install \
        --namespace "${namespace}" \
        --reset-values \
        --timeout 1h;
then
    echo "Upgrade of ${release_name} release has failed."
    exit 1
fi
