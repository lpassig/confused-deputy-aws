#!/bin/bash
set -e
# Update and install dependencies

sudo apt-get update -y
sudo apt-get install -y gnupg unzip curl wget jq git nginx

# Install Docker (official instructions for Ubuntu 22.04)
sudo apt-get install -y ca-certificates apt-transport-https software-properties-common lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose (v2, as a Docker plugin)
sudo apt-get install -y docker-compose-plugin

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Install Mongosh Shell for Ubuntu Jammy (22.04)
# https://www.mongodb.com/docs/mongodb-shell/install/

# Create the /etc/apt/sources.list.d/mongodb-org-7.0.list file for Ubuntu 22.04 (Jammy)
wget -qO- https://www.mongodb.org/static/pgp/server-7.0.asc | sudo tee /etc/apt/trusted.gpg.d/server-7.0.asc
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Reload local package and install mongosh
sudo apt-get update
sudo apt-get install -y mongodb-mongosh

# Check mongosh version
runuser -l ubuntu -c 'mongosh --version'

# Write Vault username and password to .bashrc
echo 'export VAULT_ADDR="${vault_public_endpoint_url}"' >> /home/ubuntu/.bashrc
echo 'export VAULT_TOKEN="${vault_admin_token}"' >> /home/ubuntu/.bashrc
echo 'export VAULT_NAMESPACE="admin"' >> /home/ubuntu/.bashrc

# Install Vault
VAULT_VERSION="1.20.2+ent" # Using a valid recent version
curl -fsSL https://releases.hashicorp.com/vault/"$VAULT_VERSION"/vault_"$VAULT_VERSION"_linux_amd64.zip -o vault.zip
unzip vault.zip
sudo mv vault /usr/local/bin/
rm vault.zip

echo "Creating products collection in DocumentDB..."

# Create a temporary JavaScript file for MongoDB operations
cat > /tmp/init_collection.js << 'JSEOF'
// Switch to test database
db = db.getSiblingDB('test');

// Create products collection
db.createCollection('products');

// Insert sample products
db.products.insertMany([
    {
        "_id": ObjectId(),
        "name": "Laptop",
        "price": 1299.99,
    },
    {
        "_id": ObjectId(),
        "name": "Wireless Mouse",
        "price": 29.99,
    },
    {
        "_id": ObjectId(),
        "name": "Mechanical Keyboard",
        "price": 149.99,
    }
]);

// List all documents in products collection
print("Products in collection:");
db.products.find().pretty();
JSEOF

# Execute the JavaScript file using mongosh
mongosh "mongodb://${docdb_username}:${docdb_password}@${docdb_cluster_endpoint}:27017/?retryWrites=false" /tmp/init_collection.js

echo "Products collection initialized successfully!"

# Clean up
rm /tmp/init_collection.js

# Configure nginx to listen on 8080 and proxy to internal services
sudo tee /etc/nginx/sites-available/products >/dev/null <<'NGINX'
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;

    # Health endpoint for ALB
    location = /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # ProductsWeb (Streamlit) running on 127.0.0.1:8501
    location / {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_pass http://127.0.0.1:8501/;
    }

    # ProductsAgent API on 127.0.0.1:8001
    location /api/agent/ {
        proxy_set_header Host $host;
        proxy_pass http://127.0.0.1:8001/;
    }

    # ProductsMCP API on 127.0.0.1:8000
    location /api/mcp/ {
        proxy_set_header Host $host;
        proxy_pass http://127.0.0.1:8000/;
    }
}
NGINX

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/products /etc/nginx/sites-enabled/products
sudo systemctl enable --now nginx