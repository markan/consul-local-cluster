#!/usr/bin/env bash

set -euxo pipefail

PATH=$PATH:./bin

VAULT=./bin/vault
CONSUL=./bin/consul
echo $(which vault)

TEMP_DIR=".temp"
mkdir -p $TEMP_DIR
export VAULT_ADDR='http://127.0.0.1:8200'

if [ ! -f $TEMP_DIR/vault-init.json ]; then
     $VAULT operator init --address $VAULT_ADDR --format json -n 1 -t 1 > $TEMP_DIR/vault-init.json
fi

UNSEAL_KEY=$(cat $TEMP_DIR/vault-init.json| jq -r '.unseal_keys_hex[]')
echo "Unsealing with $UNSEAL_KEY"
$VAULT operator unseal $UNSEAL_KEY

ROOT_TOKEN=`cat $TEMP_DIR/vault-init.json|jq -r '.root_token'`

export VAULT_TOKEN=$ROOT_TOKEN
$VAULT namespace create base
$VAULT namespace create aceofbase
$VAULT namespace create --namespace base namespace1
$VAULT namespace create --namespace base namespace2

sed "s/{{VAULT_TOKEN}}/${ROOT_TOKEN}/g" templates/vault-provider.json.template > $TEMP_DIR/vault-provider.json

$CONSUL acl bootstrap --format json | jq -r '.SecretID' > $TEMP_DIR/acl-token
export CONSUL_HTTP_TOKEN=`cat $TEMP_DIR/acl-token`
echo "CONSUL_HTTP_TOKEN $CONSUL_HTTP_TOKEN"
$CONSUL connect ca set-config  -config-file $TEMP_DIR/vault-provider.json
