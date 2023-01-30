#!/bin/sh
create_ca()
{
PASSWORD=$(openssl rand -base64 32)
openssl genrsa -passout pass:"$PASSWORD" -des3 -out ${CAFILE}.pass.key 2048
openssl rsa -passin pass:"$PASSWORD" -in ${CAFILE}.pass.key -out ${CAFILE}.key
openssl req -x509 -new -nodes -key ${CAFILE}.key -subj "${CASUBJECT}" -days 3650 -reqexts v3_req -extensions v3_ca -out ${CAFILE}.crt
}

create_certs()
{

CACERT=/ca/${CAFILE}.crt
CAKEY=/ca/${CAFILE}.key

openssl genrsa -out $DOMAIN.key 2048
openssl req -new -key $DOMAIN.key -out $DOMAIN.csr \
-subj "/C=ES/ST=Valencia/L=Valencia/O=EcommPro SL/OU=IT/CN=$DOMAIN"

cat <<EOF > extfile
authorityKeyIdentifier = keyid,issuer
basicConstraints = CA:false
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.$DOMAIN
DNS.2 = $DOMAIN
EOF

openssl x509 -req -in $DOMAIN.csr -CA $CACERT -CAkey $CAKEY -CAcreateserial -out $DOMAIN.crt -days 3650 -sha256 -extfile extfile

rm extfile

cat $DOMAIN.crt $DOMAIN.key > $DOMAIN.pem

ln -s $DOMAIN.crt domain.crt
ln -s $DOMAIN.key domain.key
ln -s $DOMAIN.pem domain.pem
}

( [ ! -f /ca/${CAFILE}.crt ] || [ ! -f /ca/${CAFILE}.key ] ) && ( cd /ca && create_ca )
( [ ! -f /certs/domain.crt ] || [ ! -f /certs/domain.key ] ) && ( cd /certs && create_certs )