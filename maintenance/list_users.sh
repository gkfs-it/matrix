#!/bin/bash

curl -s "http://localhost:8008/_synapse/admin/v2/users?from=0&limit=100" -H "Authorization: Bearer syt_eWFraW1lbmtvLnNh_kElEaeUBgJFfazzqpnru_0zZjzp" | python3 -m json.tool