#!/bin/bash
set -e

# --- Конфигурация ---
NEW_RELEASE_NAME="k8s-cilium"
NEW_NAMESPACE="k8s-cilium"
OLD_NAMESPACE="kube-system"
CHART_PATH="/root/helm-charts/k8s-cilium"

# --- Блок защиты от случайного исполнения ---
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "ВНИМАНИЕ: Запуск миграции Cilium из ${OLD_NAMESPACE} в ${NEW_NAMESPACE}."
echo "Убедитесь, что в ${CHART_PATH}/values.yaml установлен fullnameOverride: 'cilium'."
echo "Это действие изменит аннотации системных ресурсов, удалит DaemonSet cilium и Deployment cilium-operator."
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo -n "Введите фразу 'Yes I am sure' для продолжения: "
read -r CONFIRMATION

if [ "${CONFIRMATION}" != "Yes I am sure" ]; then
    echo "Ошибка: Введена неверная фраза. Выход."
    exit 1
fi

echo "=== Шаг 1: Аннотирование Cluster-wide ресурсов (Adoption) ==="

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
        echo "[ADOPT] Привязываю ${res} к релизу ${NEW_RELEASE_NAME}..."
        kubectl annotate "${r_type}" "${r_name}" meta.helm.sh/release-name="${NEW_RELEASE_NAME}" --overwrite
        kubectl annotate "${r_type}" "${r_name}" meta.helm.sh/release-namespace="${NEW_NAMESPACE}" --overwrite
        kubectl label "${r_type}" "${r_name}" app.kubernetes.io/managed-by=Helm --overwrite
    else
        echo "[SKIP] ${res} не найден, пропускаю."
    fi
done

echo "=== Шаг 2: Отключение старого управления в ${OLD_NAMESPACE} ==="

# Удаляем старый DaemonSet 'сиротским' способом, чтобы поды продолжали работать
if kubectl get ds cilium -n "${OLD_NAMESPACE}" &>/dev/null; then
    echo "Удаляю старый DaemonSet (cascade=orphan)..."
    kubectl delete ds cilium -n "${OLD_NAMESPACE}" --cascade=orphan
else
    echo "Старый DaemonSet 'cilium' в ${OLD_NAMESPACE} не обнаружен."
fi

# Удаляем старый оператор
echo "Удаляю старый оператор из ${OLD_NAMESPACE}..."
kubectl delete -n "${OLD_NAMESPACE}" deploy cilium-operator --ignore-not-found

echo "=== Шаг 3: Деплой нового чарта из ${CHART_PATH} с fullnameOverride: \"cilium\" ==="
/root/helm-charts/deploy.sh
read -p "If helm-diff is ok, let's deploy new chart. Hit Enter."
/root/helm-charts/deploy.sh deploy

echo "=== Шаг 4: Деплой нового чарта из ${CHART_PATH} с fullnameOverride: \"\" ==="
read -p "Please change fullnameOverride of ${CHART_PATH} back to \"\". Then hit Enter to deploy resources with new names."
/root/helm-charts/deploy.sh
read -p "If helm-diff is ok, let's deploy new chart. Hit Enter."
/root/helm-charts/deploy.sh deploy
