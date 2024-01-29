#!/bin/bash

set -e

# Base directory for Terraform modules
base_dir="$(pwd)/modules"

# Function to get output from a Terraform module
get_terraform_output() {
    module_path=$1
    output_name=$2

    cd "${base_dir}/${module_path}"
    terraform output -raw "${output_name}"
}

# Get cluster names from Terraform outputs
CLUSTER_1=$(get_terraform_output "eks/eks_cluster_1" "cluster1_name")
CLUSTER_2=$(get_terraform_output "eks/eks_cluster_2" "cluster2_name")

# Set AWS region and account number
AWS_DEFAULT_REGION=$(aws configure get region)
AWS_ACCOUNT_NUMBER=$(aws sts get-caller-identity --query "Account" --output text)

# Update kubeconfig for both clusters
aws eks update-kubeconfig --name "$CLUSTER_1" --region "$AWS_DEFAULT_REGION"
aws eks update-kubeconfig --name "$CLUSTER_2" --region "$AWS_DEFAULT_REGION"

# Define context names
CTX_CLUSTER_1=arn:aws:eks:$AWS_DEFAULT_REGION:${AWS_ACCOUNT_NUMBER}:cluster/$CLUSTER_1
CTX_CLUSTER_2=arn:aws:eks:$AWS_DEFAULT_REGION:${AWS_ACCOUNT_NUMBER}:cluster/$CLUSTER_2

# Create namespace and deploy applications
kubectl create --context="${CTX_CLUSTER_1}" namespace demo
kubectl create --context="${CTX_CLUSTER_2}" namespace demo

kubectl label --context="${CTX_CLUSTER_1}" namespace demo istio-injection=enabled
kubectl label --context="${CTX_CLUSTER_2}" namespace demo istio-injection=enabled

kubectl apply --context="${CTX_CLUSTER_1}" -f "${base_dir}/test_connectivity/helloworld.yaml" -l service=helloworld -n demo
kubectl apply --context="${CTX_CLUSTER_2}" -f "${base_dir}/test_connectivity/helloworld.yaml" -l service=helloworld -n demo

kubectl apply --context="${CTX_CLUSTER_1}" -f "${base_dir}/test_connectivity/helloworld.yaml" -l version=v1 -n demo
kubectl apply --context="${CTX_CLUSTER_2}" -f "${base_dir}/test_connectivity/helloworld.yaml" -l version=v2 -n demo

kubectl apply --context="${CTX_CLUSTER_1}" -f "${base_dir}/test_connectivity/sleep.yaml" -n demo
kubectl apply --context="${CTX_CLUSTER_2}" -f "${base_dir}/test_connectivity/sleep.yaml" -n demo

# Function to test connectivity
test_connectivity() {
    context=$1
    for i in {1..4}; do
        sleep_pod=$(kubectl get pod --context="$context" -n demo -l app=sleep -o jsonpath='{.items[0].metadata.name}')
        response=$(kubectl exec --context="$context" -n demo -c sleep "$sleep_pod" -- curl -sS helloworld.demo:5000/hello)
        echo "Response from cluster ($context): $response"
    done
}

# Test connectivity from both clusters
echo "Testing connectivity from Cluster 1"
test_connectivity "$CTX_CLUSTER_1"

echo "Testing connectivity from Cluster 2"
test_connectivity "$CTX_CLUSTER_2"
