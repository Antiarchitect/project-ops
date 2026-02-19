#!/bin/bash

# Функция для парсинга аргумента ns/kind/name или ns/name (по умолчанию kind=cm)
parse_resource() {
  local parts=(${1//\// })
  if [ ${#parts[@]} -eq 3 ]; then
    echo "${parts[0]} ${parts[1]} ${parts[2]}" # ns kind name
  elif [ ${#parts[@]} -eq 2 ]; then
    echo "${parts[0]} cm ${parts[1]}"           # ns cm name
  else
    echo "error"
  fi
}

if [ "$#" -ne 2 ]; then
    echo "Использование: $0 <ns/kind/name> <ns/kind/name>"
    echo "Примеры:"
    echo "  $0 dev/cm/app-conf prod/cm/app-conf"
    echo "  $0 dev/secret/db-creds prod/secret/db-creds"
    exit 1
fi

# Читаем параметры для обоих ресурсов
read -r NS1 KIND1 NAME1 <<< $(parse_resource "$1")
read -r NS2 KIND2 NAME2 <<< $(parse_resource "$2")

if [[ "$NS1" == "error" || "$NS2" == "error" ]]; then
    echo "Ошибка: Используйте формат namespace/kind/name"
    exit 1
fi

# Получаем объекты
RES1=$(kubectl get "$KIND1" "$NAME1" -n "$NS1" -o json 2>/dev/null)
RES2=$(kubectl get "$KIND2" "$NAME2" -n "$NS2" -o json 2>/dev/null)

if [[ -z "$RES1" || -z "$RES2" ]]; then
    echo "Ошибка: Один из ресурсов не найден."
    exit 1
fi

echo "--- Сравнение: $NS1/$KIND1/$NAME1 <-> $NS2/$KIND2/$NAME2 ---"

# jq логика:
# 1. Выбирает .data (для CM/Secret) или .spec (для Deploy/Service и т.д.)
# 2. Если это Secret, декодирует значения из base64 для читаемости
jq -n \
  --argjson obj1 "$RES1" \
  --argjson obj2 "$RES2" \
  '
  def get_payload(obj):
    if obj.kind == "Secret" then
      (obj.data // {} | map_values(@base64d))
    elif obj.data then
      obj.data
    else
      obj.spec
    end;

  get_payload($obj1) as $d1 |
  get_payload($obj2) as $d2 |

  ((($d1 | keys_unsorted) + ($d2 | keys_unsorted)) | unique)[] |
  select($d1[.] != $d2[.]) |
  {
    key: .,
    "src (\($obj1.metadata.namespace))": $d1[.],
    "dst (\($obj2.metadata.namespace))": $d2[.]
  }
  '
