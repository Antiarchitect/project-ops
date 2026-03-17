#!/bin/bash

# Функция для развертывания диапазонов: host-[01:05].com
expand_hosts() {
    local pattern="${1}"
    # Регулярное выражение ловит префикс, старт, стоп и суффикс
    if [[ "${pattern}" =~ ^(.*)\[([0-9]+):([0-9]+)\](.*)$ ]]; then
        local prefix="${BASH_REMATCH[1]}"
        local start="${BASH_REMATCH[2]}"
        local end="${BASH_REMATCH[3]}"
        local suffix="${BASH_REMATCH[4]}"
        
        # Определяем ширину числа для сохранения ведущих нулей
        local width="${#start}"
        
        for ((i=10#${start}; i<=10#${end}; i++)); do
            printf "%s%0${width}d%s\n" "${prefix}" "${i}" "${suffix}"
        done
    else
        echo "${pattern}"
    fi
}

# Список паттернов хостов
HOST_PATTERNS=("acme-0[1:5].example.com" "backup-server.local")

# Собираем итоговый массив
ALL_HOSTS=()
for p in "${HOST_PATTERNS[@]}"; do
    while read -r host; do
        ALL_HOSTS+=("${host}")
    done < <(expand_hosts "${p}")
done

# Цикл выполнения
for HOST in "${ALL_HOSTS[@]}"; do
    echo ">>> Running on: ${HOST}"
    
    ssh -o ConnectTimeout=5 "${HOST}" /bin/bash << 'EOF'
        echo "Hostname: $(hostname)"
        echo "Disk usage:"
        df -h / | tail -n 1
EOF

    echo "<<< Finished ${HOST}"
done
