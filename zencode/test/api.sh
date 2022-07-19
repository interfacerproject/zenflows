#!/bin/bash
#
# simple shell script to test the api

conf="rngseed=hex:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

# eddsa public key will always be: Lotmt4Of+Ca93Jxfvqz4I+gXCJkAVA0tcaFczuyxZNs=
zenroom -c $conf -z ../../zencode/keygen.zen | tee keyring.json | jq .

query='hello world! this should be a $mutation'

cat <<EOF > query.json
{"graphql": "$(echo $query | base64)"}
EOF
zenroom -c $conf -z ../../zencode/sign_graphql.zen -a query.json -k keyring.json | tee signed_query.json | jq .

echo "Body: $query"
echo "Header: `awk -F'"' '/eddsa_signature/ {print $4}' signed_query.json`"

# TODO: continue
