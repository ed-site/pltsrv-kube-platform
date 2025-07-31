#!/bin/bash

# Set variables
CONFIG_FILE="dev/openssl.cnf"
PRIVATE_KEY="dev/certs/private.key"
CERTIFICATE="dev/certs/certificate.crt"
VALIDITY_DAYS="365"
KEY_SIZE="4096"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Generating TLS certificate using OpenSSL...${NC}"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Config file $CONFIG_FILE not found!${NC}"
    exit 1
fi

# Create certs directory if it doesn't exist
mkdir -p dev/certs

# Generate private key WITHOUT encryption (no passphrase)
echo -e "${YELLOW}Generating private key (${KEY_SIZE} bits, unencrypted)...${NC}"
openssl genrsa -out $PRIVATE_KEY $KEY_SIZE

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Private key generated successfully${NC}"
else
    echo -e "${RED}✗ Failed to generate private key${NC}"
    exit 1
fi

# Generate certificate using the config
echo -e "${YELLOW}Generating certificate (valid for ${VALIDITY_DAYS} days)...${NC}"
openssl req -new -x509 -key $PRIVATE_KEY -out $CERTIFICATE -days $VALIDITY_DAYS -config $CONFIG_FILE

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Certificate generated successfully${NC}"
else
    echo -e "${RED}✗ Failed to generate certificate${NC}"
    exit 1
fi

# Verify the certificate
echo -e "${YELLOW}Certificate details:${NC}"
openssl x509 -in $CERTIFICATE -text -noout | grep -E "(Subject:|Subject Alternative Name|Not Before|Not After)"

# Set proper permissions
chmod 600 $PRIVATE_KEY
chmod 644 $CERTIFICATE

echo -e "${GREEN}Certificate generation complete!${NC}"
echo -e "${YELLOW}Files created:${NC}"
echo -e "  - Private key: ${GREEN}$PRIVATE_KEY${NC} (permissions: 600)"
echo -e "  - Certificate: ${GREEN}$CERTIFICATE${NC} (permissions: 644)"

# Display certificate info
echo -e "${YELLOW}Certificate Subject Alternative Names:${NC}"
openssl x509 -in $CERTIFICATE -text -noout | grep -A 5 "Subject Alternative Name" 