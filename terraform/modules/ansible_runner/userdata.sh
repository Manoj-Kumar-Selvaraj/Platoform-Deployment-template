#!/bin/bash
set -euo pipefail

# Update system
dnf update -y

# Install Python 3 and pip
dnf install -y python3 python3-pip git jq unzip

# Install Ansible
pip3 install ansible boto3 botocore

# Install Ansible collections
ansible-galaxy collection install amazon.aws community.docker community.general

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker

# Install AWS CLI v2
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install kubectl
curl -sLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

# Install Helm
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Tag instance as ready
echo "Ansible runner bootstrap complete for ${project_name}" > /var/log/bootstrap-complete.log
