#!/bin/bash

keyVaultName=$1
userName=$2
namePrefix=$3
passLen=$4

#
# Register the user name as secret in Key Vault
#
az keyvault secret set --vault-name "$keyVaultName" --name "$namePrefix-usernname" --value "$userName"

#
#
# Create a new SSH key with a random passphrase and store it all in Key Vault
#
if [ -f "./$4_rsa" ]; then
    rm ./id_rsa* --force
fi

phrase=$(openssl rand -base64 "$passLen")
ssh-keygen -t rsa -b 4096 -C "$4-DevVM-SSHKey" -N "$phrase" -f ./id_rsa -q
az keyvault secret set --vault-name "$keyVaultName" --name "$namePrefix-ssh-phrase" --value "$phrase"
az keyvault secret set --vault-name "$keyVaultName" --name "$namePrefix-ssh" --file ./id_rsa --encoding ascii
az keyvault secret set --vault-name "$keyVaultName" --name "$namePrefix-ssh-pub" --file ./id_rsa.pub --encoding ascii
rm ./id_rsa* --force

#
# Next create a random password and store it in Key Vault
#
pwd=$(openssl rand -base64 "$passLen")
az keyvault secret set --vault-name "$keyVaultName" --name "$namePrefix-pwd" --value "$pwd"