#!/bin/bash

NEW_RELEASE_NAME="k8s-cilium"
NEW_NAMESPACE="k8s-cilium"

RESOURCES=(
    "crd/ciliumnetworkpolicies.cilium.io"
    "crd/ciliumclusterwidenetworkpolicies.cilium.io"
    "crd/ciliumendpoints.cilium.io"
    "crd/ciliumnodes.cilium.io"
    "crd/ciliumidentities.cilium.io"
    "crd/ciliumlocalredirectpolicies.cilium.io"
    "crd/ciliumegressgatewaypolicies.cilium.io"
    "crd/ciliumnodeconfigs.cilium.io"
    "clusterrole/cilium"
    "clusterrole/cilium-operator"
    "clusterrolebinding/cilium"
    "clusterrolebinding/cilium-operator"
)

for res in "${RESOURCES[@]}"; do
    IFS="/" read -r r_type r_name <<< "${res}"
    if kubectl get "${r_type}" "${r_name}" &>/dev/null; then
        kubectl annotate "${r_type}" "${r_name}" meta.helm.sh/release-name="${NEW_RELEASE_NAME}" --overwrite
        kubectl annotate "${r_type}" "${r_name}" meta.helm.sh/release-namespace="${NEW_NAMESPACE}" --overwrite
        kubectl label "${r_type}" "${r_name}" app.kubernetes.io/managed-by=Helm --overwrite
        echo "Adopted ${res}"
    fi
done
