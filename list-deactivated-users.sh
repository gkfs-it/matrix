#!/bin/bash
# Список деактивованих користувачів Synapse
# Використання: ./list-deactivated-users.sh

docker exec -it synapse-postgres psql -U synapse -c \
  "SELECT name, admin, to_timestamp(creation_ts) AS created
   FROM users
   WHERE deactivated = 1
   ORDER BY creation_ts;"
