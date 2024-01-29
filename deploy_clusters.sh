#!/bin/bash

set -e

# Base directory for Terraform modules
base_dir="$(pwd)/modules"

# Directory for test connectivity scripts
test_connectivity_dir="$(pwd)/test_connectivity"

# Define the sequence of modules for VPC and EKS setup
vpc_eks_modules=("vpc/vpc_cluster_1" "eks/eks_cluster_1" "vpc/vpc_cluster_2" "eks/eks_cluster_2")

# Define the sequence of modules for Istio setup
istio_modules=("istio/istio_cluster_1" "istio/istio_cluster_2" "istio/expose_apps_cluster_1" "istio/expose_apps_cluster_2")

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

# Deploy Istio modules for both clusters
echo "Starting deployment for Istio modules..."
for submodule in "${istio_modules[@]}"; do
    deploy_module "${submodule}"
done
echo "Deployment completed for Istio modules."

# Prompt for test connectivity execution
read -p "Do you want to execute the Istio multi-cluster connectivity test? (yes/no): " execute_test
if [[ "$execute_test" == "yes" ]]; then
    echo "Starting Istio multi-cluster connectivity test..."
    test_connectivity_script="${test_connectivity_dir}/test_connectivity.sh"
    if [ -f "$test_connectivity_script" ]; then
        chmod +x "$test_connectivity_script"
        "$test_connectivity_script"
    else
        echo "Test connectivity script not found: $test_connectivity_script"
    fi
else
    echo "Skipping Istio multi-cluster connectivity test."
fi

echo "All clusters with all modules have been deployed successfully!"
