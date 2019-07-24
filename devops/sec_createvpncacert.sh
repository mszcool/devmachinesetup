keyVaultName=$1
commonName=$2
certName=$3

#
# Generate the new key ca root certificate
#

# Testing if this works on hosted agents or if I need my own agent
# Although knowing the answer probably, it's worth an attempt
apt install -y strongswan-ikev2 strongswan-plugin-eap-tls
apt install -y libstrongswan-standard-plugins

ipsec pki --gen --outform pem > cakey.pem
ipsec pki --self --in cakey.pem --dn "$commonName" --ca --outform pem > cacert.pem

#
# Next store the certificate and key in KeyVault (assumes the signed-in az cli identity has access to the respective Key Vault)
# Note: the RSA key needs to be converted into a PKCS#8 key, combined with the public key portion of the cert and then imported into KeyVault
#
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in cakey.pem -out cakey.der
cat cakey.der > cacertwithpriv.pem
cat cacert.pem >> cacertwithpriv.pem
az keyvault certificate import --vault-name "$keyVaultName" --name $certName --file cacertwithpriv.pem

#
# Delete the local files
#
rm cakey.pem --force
rm cacert.pem --force
rm cakey.der --force
rm cacertwithpriv.pem --force