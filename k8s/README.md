This `k8s/` folder contains Kubernetes manifests and step-by-step instructions to run the HRM app locally (Minikube) and on EKS.

Files:
- `deployment.yaml` - Deployment for the HRM web app. Replace `REPLACE_WITH_IMAGE` with your image for EKS, or use a local image tag for Minikube (`hrm-web:local`).
- `service.yaml` - ClusterIP service exposing port 5000.
- `ingress.yaml` - Optional ingress for nginx ingress controller.
- `secret.yaml` - Template secret (uses `stringData` so you can edit values and `kubectl apply -f secret.yaml`).

Minikube (local development)
----------------------------
Prereqs: `minikube`, `kubectl`, `docker` installed.

1. Start Minikube (optional: increase CPU/memory):

```powershell
minikube start --memory=4096 --cpus=2
```

2. Build the Docker image and load into Minikube:

```powershell
# Build image locally
docker build -t hrm-web:local HRM/

# Load into minikube
minikube image load hrm-web:local
```

3. Create namespace and apply manifests (use `hrm-web:local` in `deployment.yaml`):

```powershell
kubectl create namespace hrm-test
# edit k8s/deployment.yaml and set image: hrm-web:local
kubectl apply -f k8s/ -n hrm-test
kubectl rollout status deployment/hrm-web -n hrm-test
kubectl get pods,svc -n hrm-test
kubectl port-forward svc/hrm-service 5000:5000 -n hrm-test
# open http://localhost:5000
```

4. Create secrets (recommended instead of `secret.yaml`):

```powershell
kubectl -n hrm-test create secret generic hrm-secrets \
  --from-literal=OKTA_DOMAIN='https://dev-123456.okta.com' \
  --from-literal=OKTA_API_TOKEN='REPLACE_ME' \
  --from-literal=SECRET_KEY='REPLACE_ME' \
  --from-literal=DATABASE_HOST='mysql-host' \
  --from-literal=DATABASE_PORT='3306' \
  --from-literal=DATABASE_NAME='hrm_db' \
  --from-literal=DATABASE_USER='hrm_user' \
  --from-literal=DATABASE_PASSWORD='hrm_password'
```

EKS (cloud deployment)
----------------------
Prereqs: `aws` CLI configured, `eksctl`, `kubectl`, `docker`.

1. Create the cluster using `eksctl` (example):

```powershell
eksctl create cluster --name hrm-test --region eu-central-1 --nodegroup-name hrm-nodes --node-type t3.medium --nodes 2 --nodes-min 1 --nodes-max 3 --managed
```

2. Create an ECR repo and push image:

```powershell
$account = (aws sts get-caller-identity --query Account --output text)
$repo = "$account.dkr.ecr.eu-central-1.amazonaws.com/hrm-web:latest"
aws ecr create-repository --repository-name hrm-web --region eu-central-1 || echo 'repo exists'
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin "$account.dkr.ecr.eu-central-1.amazonaws.com"
docker build -t hrm-web:latest HRM/
docker tag hrm-web:latest $repo
docker push $repo
```

3. Update `k8s/deployment.yaml` image to point to ECR image (use full `$repo`).

4. Create namespace, create secrets, and apply manifests (same as Minikube steps but use ECR image):

```powershell
kubectl create namespace hrm-test
kubectl -n hrm-test create secret generic hrm-secrets \
  --from-literal=OKTA_DOMAIN='https://dev-123456.okta.com' \
  --from-literal=OKTA_API_TOKEN='REPLACE_ME' \
  --from-literal=SECRET_KEY='REPLACE_ME' \
  --from-literal=DATABASE_HOST='rds-endpoint' \
  --from-literal=DATABASE_PORT='3306' \
  --from-literal=DATABASE_NAME='hrm_db' \
  --from-literal=DATABASE_USER='hrm_user' \
  --from-literal=DATABASE_PASSWORD='hrm_password'

kubectl apply -f k8s/ -n hrm-test
kubectl rollout status deployment/hrm-web -n hrm-test
kubectl get pods,svc -n hrm-test
```

Notes
-----
- For ECR on EKS, managed nodegroups have IAM permissions to pull images by default; if using a custom registry, create `imagePullSecrets`.
- Keep secrets out of Git. Use `kubectl create secret` or store in AWS Secrets Manager and use External Secrets to inject them into the cluster for production.
- If you want, I can update `k8s/deployment.yaml` now with a sample ECR image value if you share your AWS account ID or the repository path.
