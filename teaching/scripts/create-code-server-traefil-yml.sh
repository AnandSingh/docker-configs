#!/bin/bash

# Define the input array
declare -A inputs=(
  [abby]=8447
  [alice]=8445
  [anand]=8453
  [anshi]=8444
  [elly]=8448
  [emma]=8446
  [jessica]=8452
  [nitya]=8450
  [paige]=8451
)

# IP address for services
SERVER_IP="192.168.10.46"
DOMAIN="tinkeringturtle.site"

# Loop through each user to create respective YAML files
for name in "${!inputs[@]}"; do
  port="${inputs[$name]}"
  filename="${name}-code-server.yml"

  cat > "$filename" <<EOF
http:
  routers:
    ${name}-code-server:
      rule: "Host(\`${name}.${DOMAIN}\`)"
      entryPoints:
        - websecure
      service: ${name}-code-server
  services:
    ${name}-code-server:
      loadBalancer:
        servers:
          - url: "http://${SERVER_IP}:${port}"
EOF

  echo "Created ${filename}"
done
