param(
    [string]$Region = 'eu-central-1',
    [string]$ClusterName = 'hrm-test',
    [string]$EcrRepo = 'hrm-web',
    [string]$ImageTag = 'latest',
    [switch]$SkipClusterCreation
)

function Check-Command($cmd) {
    $which = (Get-Command $cmd -ErrorAction SilentlyContinue)
    if (-not $which) {
        Write-Error "Required command '$cmd' not found in PATH. Please install and configure it."
        exit 1
    }
}

# Prereqs
Check-Command aws
Check-Command docker
Check-Command kubectl
Check-Command eksctl

$ErrorActionPreference = 'Stop'

# Get AWS account ID
$account = (aws sts get-caller-identity --query Account --output text) -replace '\n',''
if (-not $account) { Write-Error 'Failed to determine AWS account ID. Run `aws configure` first.'; exit 1 }
# build repo URI safely (avoid ambiguous variable parsing in double-quoted string)
$repoUri = "$($account).dkr.ecr.$Region.amazonaws.com/$($EcrRepo):$($ImageTag)"
Write-Host "Using ECR repo: $repoUri"

# Create ECR repo if it doesn't exist
try {
    aws ecr describe-repositories --repository-names $EcrRepo --region $Region | Out-Null
    Write-Host "ECR repository '$EcrRepo' already exists"
} catch {
    Write-Host "Creating ECR repository '$EcrRepo'..."
    aws ecr create-repository --repository-name $EcrRepo --region $Region | Out-Null
}

# Login to ECR
Write-Host "Logging in to ECR..."
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin "$account.dkr.ecr.$Region.amazonaws.com"

# Build and push image
Write-Host "Building Docker image 'hrm-web:$ImageTag' from HRM/ directory..."
docker build -t hrm-web:$ImageTag HRM/
Write-Host "Tagging image as $repoUri"
docker tag hrm-web:$ImageTag $repoUri
Write-Host "Pushing image to ECR..."
docker push $repoUri

# Create EKS cluster (optional)
if (-not $SkipClusterCreation) {
    Write-Host "Creating EKS cluster '$ClusterName' in region $Region using eksctl (this may take 10-20 minutes)..."
    eksctl create cluster --name $ClusterName --region $Region --nodegroup-name ${ClusterName}-nodes --node-type t3.medium --nodes 2 --nodes-min 1 --nodes-max 3 --managed
} else {
    Write-Host "Skipping cluster creation (--SkipClusterCreation provided). Ensure kubeconfig is set and points to the target cluster."
}

# Ensure kubectl can talk to cluster
Write-Host "Verifying kubectl connectivity..."
$kubectlVersion = & kubectl version --client 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "kubectl is not configured or cannot reach a cluster. If you just created the cluster, ensure kubeconfig is updated (aws eks update-kubeconfig --name $ClusterName --region $Region) or re-run the script without -SkipClusterCreation to let eksctl create it. Exiting."
    exit 1
} else {
    Write-Host $kubectlVersion
}

$namespace = 'hrm-test'
# Create namespace if not exists
if (-not (& kubectl get namespace $namespace -o name 2>$null)) {
    kubectl create namespace $namespace
}

# Create Kubernetes secret from HRM/.env
$envPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'HRM\.env'
if (-not (Test-Path $envPath)) {
    Write-Error ".env file not found at $envPath. Create it or export secrets manually."; exit 1
}

Write-Host "Reading environment values from $envPath"
$lines = Get-Content $envPath | Where-Object { $_ -match '\S' -and $_ -notmatch '^#' }
$kv = @{}
foreach ($l in $lines) {
    $parts = $l -split '='
    if ($parts.Count -ge 2) {
        $key = $parts[0].Trim()
        $value = ($parts[1..($parts.Count -1)] -join '=').Trim()
        $kv[$key] = $value
    }
}

# Delete existing secret if present
if (kubectl get secret hrm-secrets -n $namespace -o name 2>$null) {
    Write-Host "Replacing existing secret 'hrm-secrets' in namespace $namespace"
    kubectl delete secret hrm-secrets -n $namespace
}

# Build kubectl create secret arguments to avoid quoting/Invoke-Expression issues
$createArgs = @('-n', $namespace, 'create', 'secret', 'generic', 'hrm-secrets')
foreach ($k in $kv.Keys) {
    # use kubectl argument form --from-literal=KEY=VALUE
    $createArgs += "--from-literal=$k=$($kv[$k])"
}
Write-Host "Creating Kubernetes secret from .env"
Write-Host "kubectl $($createArgs -join ' ')"
& kubectl @createArgs

# Update k8s/deployment.yaml image placeholder
$deploymentPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'k8s\deployment.yaml'
if (-not (Test-Path $deploymentPath)) {
    Write-Error "deployment.yaml not found at $deploymentPath"; exit 1
}

# Backup original
Copy-Item $deploymentPath "$deploymentPath.bak" -Force
(Get-Content $deploymentPath) -replace 'REPLACE_WITH_IMAGE', $repoUri | Set-Content $deploymentPath
Write-Host "Updated deployment.yaml with image $repoUri"

# Apply manifests
Write-Host "Applying manifests in k8s/ to namespace $namespace"
kubectl apply -f (Join-Path (Split-Path -Parent $PSScriptRoot) 'k8s') -n $namespace

Write-Host "Waiting for rollout..."
kubectl rollout status deployment/hrm-web -n $namespace

Write-Host "Deployment complete. Get pods and services with:"
Write-Host "  kubectl get pods,svc -n $namespace"
Write-Host "To access locally, run port-forward:"
Write-Host "  kubectl port-forward svc/hrm-service 5000:5000 -n $namespace"

Write-Host 'Done.'
