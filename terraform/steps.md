
mongosh "mongodb://ai-6rc-docdb-cluster.cluster-cxhijwmejwoe.us-east-1.docdb.amazonaws.com:27017/" --retryWrites=false --username docdbadmin --password HashiCorp123!

mongosh "mongodb://localhost:27017/" --retryWrites=false --username docdbadmin --password HashiCorp123!

ssh -fN -L 27017:ai-6rc-docdb-cluster.cluster-cxhijwmejwoe.us-east-1.docdb.amazonaws.com:27017 ubuntu@$(terraform output -raw bastion_public_ip) -i $(terraform output -raw bastion_ssh_key_path)