# OpenSSL TLS Certificate Generation Guide

This guide explains how to use OpenSSL to generate TLS certificates using the `openssl.cnf` configuration file located in the `terraform/` directory.

## Overview

The `openssl.cnf` file is configured to generate certificates for `container-platform.mckesson.com` with specific Subject Alternative Names (SANs) and security settings suitable for development and internal services.

## Configuration Details

The current `openssl.cnf` configuration includes:

- **Common Name**: `container-platform.mckesson.com`
- **Subject Alternative Names**:
  - IP: `container-platform.mckesson.com`, `127.0.0.1`
  - DNS: `localhost`
- **Key Usage**: `keyEncipherment`, `dataEncipherment`, `digitalSignature`
- **Extended Key Usage**: `serverAuth`
- **No prompts**: Automated certificate generation without user input

## Basic Certificate Generation

### 1. Generate Self-Signed Certificate (One Command)

```bash
# Generate private key and certificate in one command
openssl req -x509 -newkey rsa:4096 -keyout private.key -out certificate.crt -days 365 -config terraform/openssl.cnf
```

### 2. Generate Certificate Step by Step

```bash
# Step 1: Generate private key
openssl genrsa -out private.key 4096

# Step 2: Generate certificate using the config
openssl req -new -x509 -key private.key -out certificate.crt -days 365 -config terraform/openssl.cnf
```

## Advanced Certificate Generation

### 3. Generate Certificate Signing Request (CSR)

```bash
# Generate private key
openssl genrsa -out private.key 4096

# Generate CSR using the config
openssl req -new -key private.key -out certificate.csr -config terraform/openssl.cnf
```

### 4. Generate Certificate with Different Key Types

```bash
# Using ECDSA key (more modern, smaller size)
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout private.key -out certificate.crt -days 365 -config terraform/openssl.cnf

# Using Ed25519 key (most modern)
openssl req -x509 -newkey ed25519 -keyout private.key -out certificate.crt -days 365 -config terraform/openssl.cnf
```

### 5. Generate Certificate with Custom Validity Period

```bash
# Certificate valid for 2 years
openssl req -x509 -newkey rsa:4096 -keyout private.key -out certificate.crt -days 730 -config terraform/openssl.cnf

# Certificate valid for 10 years
openssl req -x509 -newkey rsa:4096 -keyout private.key -out certificate.crt -days 3650 -config terraform/openssl.cnf
```

## Customizing for Different Domains

### Option A: Modify Config File Temporarily

```bash
# Create a copy with your domain
sed 's/container-platform.mckesson.com/your-domain.com/g' terraform/openssl.cnf > openssl-custom.cnf

# Use the modified config
openssl req -x509 -newkey rsa:4096 -keyout private.key -out certificate.crt -days 365 -config openssl-custom.cnf
```

### Option B: Override Config Values on Command Line

```bash
openssl req -x509 -newkey rsa:4096 -keyout private.key -out certificate.crt -days 365 -config terraform/openssl.cnf -subj "/CN=your-domain.com"
```

## Certificate Verification and Inspection

### 6. Verify Generated Certificate

```bash
# View certificate details
openssl x509 -in certificate.crt -text -noout

# Verify the SANs are correct
openssl x509 -in certificate.crt -text -noout | grep -A 10 "Subject Alternative Name"

# Check certificate expiration
openssl x509 -in certificate.crt -noout -dates

# Verify certificate matches private key
openssl x509 -noout -modulus -in certificate.crt | openssl md5
openssl rsa -noout -modulus -in private.key | openssl md5
```

## Certificate Format Conversion

### 7. Convert Between Formats

```bash
# Convert to PEM format (if needed)
openssl x509 -in certificate.crt -out certificate.pem -outform PEM

# Convert to DER format
openssl x509 -in certificate.crt -out certificate.der -outform DER

# Convert to PKCS#12 format (for some applications)
openssl pkcs12 -export -out certificate.p12 -inkey private.key -in certificate.crt

# Convert from PKCS#12 to PEM
openssl pkcs12 -in certificate.p12 -out certificate.pem -nodes
```

## Complete Automation Script

### 8. Automated Certificate Generation

Create a script `generate-cert.sh`:

```bash
#!/bin/bash

# Set variables
CONFIG_FILE="terraform/openssl.cnf"
PRIVATE_KEY="private.key"
CERTIFICATE="certificate.crt"
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

# Generate private key
echo -e "${YELLOW}Generating private key (${KEY_SIZE} bits)...${NC}"
openssl genrsa -out $PRIVATE_KEY $KEY_SIZE

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Private key generated successfully${NC}"
else
    echo -e "${RED}✗ Failed to generate private key${NC}"
    exit 1
fi

# Generate certificate
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
```

Make it executable and run:

```bash
chmod +x generate-cert.sh
./generate-cert.sh
```

## Security Best Practices

### File Permissions

```bash
# Set secure permissions for private key
chmod 600 private.key

# Set appropriate permissions for certificate
chmod 644 certificate.crt
```

### Key Security

- Keep private keys secure and never share them
- Use strong passphrases if encrypting private keys
- Rotate certificates regularly
- Store private keys in secure locations

### Certificate Validation

```bash
# Validate certificate chain (if using CA-signed certificates)
openssl verify -CAfile ca.crt certificate.crt

# Check certificate against specific CA
openssl verify -CAfile /path/to/ca-bundle.crt certificate.crt
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure you have write permissions in the current directory
2. **Config File Not Found**: Verify the path to `openssl.cnf` is correct
3. **Invalid SAN**: Check that the domain names in the config match your requirements
4. **Certificate Expired**: Regenerate with a longer validity period

### Debug Commands

```bash
# Check OpenSSL version
openssl version

# Verify config file syntax
openssl req -config terraform/openssl.cnf -new -key private.key -out test.csr -batch

# Test certificate generation without saving
openssl req -x509 -newkey rsa:2048 -keyout /dev/null -out /dev/null -days 1 -config terraform/openssl.cnf
```

## Integration with Kubernetes

### Create Kubernetes Secret

```bash
# Create a Kubernetes secret with the certificate
kubectl create secret tls my-tls-secret \
  --cert=certificate.crt \
  --key=private.key \
  --namespace=default
```

### Use in Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  tls:
  - hosts:
    - container-platform.mckesson.com
    secretName: my-tls-secret
  rules:
  - host: container-platform.mckesson.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

## References

- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [OpenSSL Cookbook](https://www.feistyduck.com/library/openssl-cookbook/)
- [TLS Certificate Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)

---

**Note**: This guide is specifically tailored for the `openssl.cnf` configuration in this project. For production environments, consider using proper Certificate Authorities (CAs) and following organizational security policies. 