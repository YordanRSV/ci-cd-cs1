# This script creates an EKS cluster using eksctl.
# Ensure you have eksctl installed and configured with AWS credentials.

param(
    [string]$ClusterName = "hrm-test",
    [string]$Region = "eu-central-1",
    [string]$NodeGroupName = "hrm-nodes",
    [string]$NodeType = "t3.medium",
    [int]$Nodes = 2,
    [int]$MinNodes = 1,
    [int]$MaxNodes = 3
)

function Check-Command($cmd) {
    $which = (Get-Command $cmd -ErrorAction SilentlyContinue)
    if (-not $which) {
        Write-Error "Required command '$cmd' not found in PATH. Please install and configure it."
        exit 1
    }
}

# Prerequisites
Check-Command eksctl

Write-Host "Creating EKS cluster '$ClusterName' in region '$Region'..."

# Create the cluster
& eksctl create cluster `
    --name $ClusterName `
    --region $Region `
    --nodegroup-name $NodeGroupName `
    --node-type $NodeType `
    --nodes $Nodes `
    --nodes-min $MinNodes `
    --nodes-max $MaxNodes `
    --managed

Write-Host "EKS cluster '$ClusterName' created successfully."
Write-Host "Use 'aws eks update-kubeconfig --name $ClusterName --region $Region' to configure kubectl."