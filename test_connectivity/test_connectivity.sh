#!/bin/bash

set -e

# Define the base directory for Terraform modules
modules_dir="$(pwd)/modules"

# Function to get output from a Terraform module
get_terraform_output() {
    module_path=$1
    output_name=$2

    # Navigate to the module directory and get the output
    pushd "${modules_dir}/${module_path}" > /dev/null
    output=$(terraform output -raw "${output_name}")
    popd > /dev/null
    echo $output
}

# Get cluster names from Terraform outputs
CLUSTER_1=$(get_terraform_output "eks/eks_cluster_1" "cluster1_name")
CLUSTER_2=$(get_terraform_output "eks/eks_cluster_2" "cluster2_name")

# Check for cluster name length
if [ ${#CLUSTER_1} -gt 100 ] || [ ${#CLUSTER_2} -gt 100 ]; then
    echo "Error: Cluster names must not exceed 100 characters."
    exit 1
fi

# Set AWS region and account number
AWS_DEFAULT_REGION=$(aws configure get region)
AWS_ACCOUNT_NUMBER=$(aws sts get-caller-identity --query "Account" --output text)

# Define Kubernetes contexts
CTX_CLUSTER1=arn:aws:eks:$AWS_DEFAULT_REGION:${AWS_ACCOUNT_NUMBER}:cluster/$CLUSTER_1
CTX_CLUSTER2=arn:aws:eks:$AWS_DEFAULT_REGION:${AWS_ACCOUNT_NUMBER}:cluster/$CLUSTER_2

# Update kubeconfig for both clusters
aws eks update-kubeconfig --name "$CLUSTER_1" --region "$AWS_DEFAULT_REGION"
aws eks update-kubeconfig --name "$CLUSTER_2" --region "$AWS_DEFAULT_REGION"

# Function to create namespace and enable Istio injection
setup_namespace() {
    context=$1
    namespace=$2
    kubectl create namespace "$namespace" --context="$context" || true
    kubectl label namespace "$namespace" istio-injection=enabled --context="$context" --overwrite
}

# Setup namespaces and enable Istio injection
setup_namespace "$CTX_CLUSTER1" "demo"
setup_namespace "$CTX_CLUSTER2" "demo"

# Deploy HelloWorld and Sleep applications
kubectl apply --context="${CTX_CLUSTER1}" -f "${modules_dir}/../test_connectivity/helloworld.yaml" -l service=helloworld -n demo
kubectl apply --context="${CTX_CLUSTER2}" -f "${modules_dir}/../test_connectivity/helloworld.yaml" -l service=helloworld -n demo
kubectl apply --context="${CTX_CLUSTER1}" -f "${modules_dir}/../test_connectivity/helloworld.yaml" -l version=v1 -n demo
kubectl apply --context="${CTX_CLUSTER2}" -f "${modules_dir}/../test_connectivity/helloworld.yaml" -l version=v2 -n demo
kubectl apply --context="${CTX_CLUSTER1}" -f "${modules_dir}/../test_connectivity/sleep.yaml" -n demo
kubectl apply --context="${CTX_CLUSTER2}" -f "${modules_dir}/../test_connectivity/sleep.yaml" -n demo

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
test_connectivity "$CTX_CLUSTER1"

echo "Testing connectivity from Cluster 2"
test_connectivity "$CTX_CLUSTER2"

echo "Cross-cluster traffic test completed successfully."
