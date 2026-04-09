#!/bin/bash
set -euxo pipefail

# -------------------------------------------------------------------
# Variables passed in from Terraform templatefile()
# -------------------------------------------------------------------
K8S_VERSION="${kubernetes_version}"
POD_CIDR="${pod_cidr}"
AWS_REGION="${aws_region}"

# -------------------------------------------------------------------
# System prep
# -------------------------------------------------------------------
hostnamectl set-hostname "${node_name}"

# Disable swap — required by Kubernetes
swapoff -a
sed -i '/swap/d' /etc/fstab

# Load required kernel modules
cat <<EOF | tee /etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Kernel networking settings required by Kubernetes
cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# -------------------------------------------------------------------
# Install containerd (container runtime)
# -------------------------------------------------------------------
apt-get update -y
apt-get install -y containerd apt-transport-https ca-certificates curl gpg

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
# Use systemd cgroup driver — required for Kubernetes
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# -------------------------------------------------------------------
# Install Kubernetes components
# -------------------------------------------------------------------
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$${K8S_VERSION}/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v$${K8S_VERSION}/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Configure kubelet to use the correct node IP
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo "KUBELET_EXTRA_ARGS=--node-ip=$LOCAL_IP" | tee /etc/default/kubelet
systemctl enable kubelet

# Signal success
/opt/aws/bin/cfn-signal -e $? || true