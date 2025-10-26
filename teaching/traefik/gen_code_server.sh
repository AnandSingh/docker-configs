#!/bin/sh

# Define arrays of names and corresponding ports
NAMES=(anand ijessica paige nitya meghana elly abby emma alice anshi)
PORTS=(8453 8452 8451 8450 8449 8448 8447 8446 8445 8444)

IP="192.168.10.29"

# Loop through the arrays and generate YML files
for i in "${!NAMES[@]}"; do
    NAME=${NAMES[$i]}
    PORT=${PORTS[$i]}
    FILENAME="${NAME}-code-server.yml"

    cat <<EOL > $FILENAME
http:
  routers:
    ${NAME}-code-server:
      rule: "Host(\`${NAME}.tinkeringturtle.site\`)"
      entryPoints:
        - websecure
      service: ${NAME}-code-server
  services:
    ${NAME}-code-server:
      loadBalancer:
        servers:
          - url: "http://${IP}:${PORT}"
EOL

    echo "Generated ${FILENAME}"
done
