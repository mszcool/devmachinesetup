rgName=$1

echo "Checking if resource group $rgName exists..."
existingGroup=$(az group show --name "$rgName" --out json)
if [ "$existingGroup" ]; then
    echo "Deleting resource group $rgName..."
    az group delete --name "$rgName" --yes
else
    echo "Resource group $rgName does not exist... skipping!"
fi