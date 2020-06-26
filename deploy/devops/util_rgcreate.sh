#!/bin/bash

rgName=$1
location=$2

echo "Checking if resource group $rgName exists..."
existingGroup=$(az group show --name "$rgName" --out json)
if [ "$existingGroup" ]; then
    echo "Resource group $rgName exists, skipping creation!"
else
    echo "Creating resource group $rgName..."
    az group create --name "$rgName" --location "$location"
fi