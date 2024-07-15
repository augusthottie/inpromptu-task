#!/bin/bash

# Define the directory and file to store container details
CONTAINER_DIR="/etc/dockssh.d"
CONTAINER_FILE="$CONTAINER_DIR/containers.txt"
NGINX_CONF_DIR="/etc/nginx/conf.d"

# Create the directory if it does not exist
sudo mkdir -p $CONTAINER_DIR
sudo mkdir -p $NGINX_CONF_DIR

# Function to get the host IP address
get_host_ip() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{ print $2 }' | head -n 1
  else
    # Linux
    hostname -I | awk '{print $1}'
  fi
}

# Function to create a container
create_container() {
  local container_name=$1

  # Prompt for the container password
  read -sp "Enter password for the container: " container_password
  echo

  # Generate a unique SSH port
  while :; do
    if command -v gshuf > /dev/null 2>&1; then
      SSH_PORT=$(gshuf -i 1024-65535 -n 1)
    else
      SSH_PORT=$(jot -r 1 1024 65535)
    fi
    if ! grep -q " $SSH_PORT$" $CONTAINER_FILE 2>/dev/null; then
      break
    fi
  done

  # Create and start the Ubuntu container with resource limits
  docker run -d --name $container_name --hostname $container_name \
  --cpus="0.5" --memory="512m" \
  -p $SSH_PORT:22 ubuntu:latest /bin/bash -c "apt-get update --fix-missing && \
  apt-get install -y openssh-server nginx && \
  echo 'root:$container_password' | chpasswd && \
  sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
  service ssh start && \
  service nginx start && \
  sleep infinity"

  # Get the host IP address
  HOST_IP=$(get_host_ip)


  # Update Nginx configuration on the host
  update_nginx_host_config $container_name

  # Save the container details
  echo "$container_name $SSH_PORT" | sudo tee -a $CONTAINER_FILE


  # Display the container details
  echo "--- Container Details ---"
  echo "Container Name: $container_name"
  echo "SSH Port: $SSH_PORT"
  echo "To SSH: ssh root@$HOST_IP -p $SSH_PORT"
  echo "Please wait for the container to start... ideally 5 minutes"
  echo "-------------------------"
}

update_nginx_host_config() {
  local container_name=$1
  local container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container_name)

  # Create Nginx configuration for the container
  cat <<EOF | sudo tee $NGINX_CONF_DIR/$container_name.conf
server {
    listen 80;
    server_name $container_name.localhost;
    location / {
        proxy_pass http://$container_ip:80/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  # Reload Nginx to apply the new configuration
  sudo nginx -s reload
}

# Main script execution
if [ "$#" -ne 2 ]; then
  echo "Usage: ./dockssh create <name>"
  exit 1
fi

COMMAND=$1
CONTAINER_NAME=$2

if [ "$COMMAND" == "create" ]; then
  create_container $CONTAINER_NAME
else
  echo "Invalid command. Usage: ./dockssh create <name>"
  exit 1
fi