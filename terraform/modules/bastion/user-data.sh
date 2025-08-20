#!/bin/bash
set -e
# Update and install dependencies
sudo apt-get update -y
sudo apt-get install -y gnupg unzip curl wget jq

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