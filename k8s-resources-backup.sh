#!/usr/bin/env bash

# Backup all k8s resources: namespaced and clusterwide
# Structure:
#   <BACKUP_DIR>/
#     clusterwide/
#       <resourceType>/
#         <objectName>.yaml
#     namespaced/
#       <namespace>/
#         <resourceType>/
#           <objectName>.yaml
#
# Usage:
#   ./k8s-backup.sh [BACKUP_DIR]
# If BACKUP_DIR is not set k8s-resources-backup-<date-time> will be used

set -eo pipefail

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl не найден в PATH" >&2
  exit 1
fi

BACKUP_ROOT="${1:-k8s-resources-backup-$(date +%Y%m%d-%H%M%S)}"
BACKUP_ROOT="$(realpath "${BACKUP_ROOT}")"

mkdir -p "${BACKUP_ROOT}/clusterwide" "${BACKUP_ROOT}/namespaced"

table_pattern="| %-70s | %-7s |\n"
separator="------------------------------------------------------------------------------------"

echo "${separator}"
echo " Backup directory: ${BACKUP_ROOT}"

echo " Collecting clusterwide resources kinds..."
cluster_resources="$(kubectl api-resources --verbs=list --namespaced=false -o name | grep -v "/" | sort -u)"
echo "${separator}"

echo
echo "${separator}"
echo " Clusterwide resources backup:"
echo "${separator}"
echo
printf "${table_pattern}" "Resource" "Objects"
printf "${table_pattern}" "" "" | tr ' ' '-'
for res in ${cluster_resources}; do
    objs=$(kubectl get "${res}" -o name 2>/dev/null || true)
    obj_count=0
    res_dir="${BACKUP_ROOT}/clusterwide/${res}"

    for obj in ${objs}; do
        name="${obj#*/}"

        test "${obj_count}" -eq "0" && mkdir -p "${res_dir}"

        kubectl get "${obj}" -o yaml > "${res_dir}/${name}.yaml" 2>/dev/null
        obj_count=$(( obj_count + 1 ))
    done

    printf "${table_pattern}" "${res}" "${obj_count}"
done

table_pattern="| %-25s | %-70s | %-7s |\n"
separator="----------------------------------------------------------------------------------------------------------------"
echo
echo "${separator}"
echo " Collecting namespaces list..."
namespaces="$(kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"

echo " Collecting namespaced resource kinds..."
ns_resources="$(kubectl api-resources --verbs=list --namespaced=true -o name | grep -v "/" | sort -u)"
echo "${separator}"

for ns in ${namespaces}; do
    echo
    echo "${separator}"
    echo " Resources backup for namespace: ${ns}"
    echo "${separator}"
    echo
    ns_dir="${BACKUP_ROOT}/namespaced/${ns}"
    mkdir -p "${ns_dir}"

    printf "${table_pattern}" "Namespace" "Resource" "Objects"
    printf "${table_pattern}" "" "" "" | tr ' ' '-'
    for res in ${ns_resources}; do
        objs=$(kubectl -n "${ns}" get "${res}" -o name 2>/dev/null || true)
        obj_count=0
        res_dir="${ns_dir}/${res}"

        for obj in ${objs}; do
            name="${obj#*/}"

            test "${obj_count}" -eq "0" && mkdir -p "${res_dir}"

            kubectl -n "${ns}" get "${obj}" -o yaml > "${res_dir}/${name}.yaml" 2>/dev/null
            obj_count=$(( obj_count + 1 ))
        done

        printf "${table_pattern}" "${ns}" "${res}" "${obj_count}"
    done
done

echo
echo "${separator}"
echo " Backup is saved to: ${BACKUP_ROOT}"
echo "${separator}"
