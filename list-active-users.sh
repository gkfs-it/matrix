#!/bin/bash
# Список активних (недеактивованих) користувачів Synapse
# Використання: ./list-active-users.sh

docker exec -it synapse-postgres psql -U synapse -c \
  "SELECT name, admin, to_timestamp(creation_ts) AS created
   FROM users
   WHERE deactivated = 0
   ORDER BY creation_ts;"
