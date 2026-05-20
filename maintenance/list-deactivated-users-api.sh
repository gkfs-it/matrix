#!/bin/bash
# Список деактивованих користувачів Synapse через Admin API
# Використання: ./list-deactivated-users-api.sh <admin_token>

ADMIN_TOKEN=$1
SERVER="http://localhost:8008"

if [ -z "$ADMIN_TOKEN" ]; then
    echo "Використання: $0 <admin_token>"
    echo "Приклад:     $0 syt_xxxxxxxxxxxx"
    exit 1
fi

docker exec synapse curl -s \
  "${SERVER}/_synapse/admin/v2/users?deactivated=true&limit=100" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | python3 -m json.tool --no-ensure-ascii
