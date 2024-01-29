#!/bin/bash

set -e

# Define the sequence of modules for each cluster
vpc_eks_modules=("vpc/vpc_cluster_1" "eks/eks_cluster_1" "vpc/vpc_cluster_2" "eks/eks_cluster_2")
istio_modules=("istio/istio_cluster_1" "istio/istio_cluster_2" "istio/expose_apps_cluster_1" "istio/expose_apps_cluster_2")

# Base directory for Terraform modules
base_dir="$(pwd)/modules"

# Function to deploy a Terraform submodule and display outputs
deploy_module() {
    submodule_path=$1
    max_retries=3
    attempt=1

    while [ $attempt -le $max_retries ]; do
        echo "Deploying ${submodule_path} (Attempt: $attempt)..."
        module_dir="${base_dir}/${submodule_path}"

        if [ -d "${module_dir}" ]; then
            cd "${module_dir}"

            # Initialize and Apply Terraform
            if terraform init -input=false && terraform apply -auto-approve -input=false; then
                # Display outputs
                echo "Outputs for ${submodule_path}:"
                terraform output
                cd -
                return 0
            else
                echo "Deployment of ${submodule_path} failed. Retrying..."
                ((attempt++))
                cd -
            fi
        else
            echo "Directory ${module_dir} does not exist. Skipping..."
            return 0
        fi
    done

    echo "Deployment of ${submodule_path} failed after ${max_retries} attempts."
    exit 1
}

# Deploy VPC and EKS modules for both clusters
echo "Starting deployment for VPC and EKS clusters..."
for submodule in "${vpc_eks_modules[@]}"; do
    deploy_module "${submodule}"
done
echo "Deployment completed for VPC and EKS clusters."

# Deploy Istio and expose_apps modules for both clusters
echo "Starting deployment for Istio and expose_apps modules..."
for submodule in "${istio_modules[@]}"; do
    deploy_module "${submodule}"
done
echo "Deployment completed for Istio and expose_apps modules."

# Execute test_connectivity script
echo "Starting Istio multi-cluster connectivity test..."
test_connectivity_script="${base_dir}/test_connectivity/test_connectivity.sh"
if [ -f "$test_connectivity_script" ]; then
    chmod +x "$test_connectivity_script"
    "$test_connectivity_script"
else
    echo "Test connectivity script not found: $test_connectivity_script"
fi

echo "All clusters and connectivity tests have been deployed successfully!"
