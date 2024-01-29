#!/bin/bash

set -e

# Define the sequence of modules for each cluster in reverse order
declare -a cluster1_modules=("istio/expose_apps_cluster_1" "istio/istio_cluster_1" "eks/eks_cluster_1" "vpc/vpc_cluster_1")
declare -a cluster2_modules=("istio/expose_apps_cluster_2" "istio/istio_cluster_2" "eks/eks_cluster_2" "vpc/vpc_cluster_2")

# Base directory for Terraform modules
base_dir="$(pwd)/modules"

# Number of retries
max_retries=3

# Function to destroy a Terraform submodule with retry logic
destroy_module() {
    submodule_path=$1
    retries=0

    echo "Destroying ${submodule_path}..."

    module_dir="${base_dir}/${submodule_path}"
    
    if [ -d "${module_dir}" ]; then
        cd "${module_dir}"

        until terraform init -input=false && terraform destroy -auto-approve -input=false; do
            echo "Attempt $((retries+1)) failed! Retrying in 5 seconds..."
            sleep 5
            retries=$((retries+1))
            if [ "$retries" -ge "$max_retries" ]; then
                echo "Failed to destroy ${submodule_path} after ${max_retries} attempts."
                exit 1
            fi
        done

        cd -
    else
        echo "Directory ${module_dir} does not exist. Skipping..."
    fi
}

# Destroy submodules for cluster2
echo "Starting cleanup for cluster2..."
for submodule in "${cluster2_modules[@]}"; do
    destroy_module "${submodule}"
done
echo "Cleanup completed for cluster2."

# Destroy submodules for cluster1
echo "Starting cleanup for cluster1..."
for submodule in "${cluster1_modules[@]}"; do
    destroy_module "${submodule}"
done
echo "Cleanup completed for cluster1."

echo "All resources have been destroyed successfully!"
