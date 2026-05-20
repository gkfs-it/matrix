#!/bin/bash
# Деактивація користувача Matrix + анулювання всіх сесій
# Використання: ./deactivate-user.sh <username>
#
# Приклад: ./deactivate-user.sh yakimenko.sa

USERNAME=$1
ADMIN_TOKEN=$2
SERVER="http://localhost:8008"
MXID="@${USERNAME}:hq.gkfs.com.ua"

if [ -z "$USERNAME" ] || [ -z "$ADMIN_TOKEN" ]; then
    echo "Використання: $0 <username> <admin_token>"
    echo "Приклад:     $0 yakimenko.sa syt_xxxxxxxxxxxx"
    exit 1
fi

echo "Деактивуємо користувача: ${MXID}"

docker exec synapse curl -s -X POST \
    "${SERVER}/_synapse/admin/v1/deactivate/${MXID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"erase": false}' | python3 -m json.tool --no-ensure-ascii
