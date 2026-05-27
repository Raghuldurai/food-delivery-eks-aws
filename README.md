# 🍔 Food Delivery App — EKS + CI/CD on AWS

A full-stack food ordering platform (React frontend, Node/Express backend, MongoDB Atlas) deployed on **AWS EKS** with a fully automated CI/CD pipeline using **Jenkins → ArgoCD → Kubernetes**.

---

## 🏗️ Architecture Overview

```
User → AWS ALB → Ingress Controller
                   ├── /         → Frontend (React + Vite)
                   ├── /api      → Backend (Node.js / Express)
                   ├── /images   → Backend (static uploads)
                   └── /admin    → Admin Panel (React + Vite)

Infrastructure (Terraform):
  VPC → EKS Cluster → ALB Controller → ArgoCD

CI/CD:
  GitHub → Jenkins → SonarQube → OWASP → Trivy → DockerHub → ArgoCD → EKS
```

---

## 🧱 Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React + Vite, served via Nginx |
| Admin Panel | React + Vite, served via Nginx |
| Backend | Node.js + Express |
| Database | MongoDB Atlas |
| Container Runtime | Docker |
| Orchestration | Kubernetes (EKS) |
| Ingress | AWS ALB Controller |
| GitOps / CD | ArgoCD |
| CI Pipeline | Jenkins |
| Code Quality | SonarQube |
| Dependency Scan | OWASP Dependency-Check |
| Image Scan | Trivy |
| IaC | Terraform (modular) |
| Cloud | AWS |

---

## 📁 Repository Structure

```
.
├── frontend/            # Customer-facing React app
├── admin/               # Admin panel React app
├── backend/             # Express REST API
├── k8s_eks/             # Kubernetes manifests (deployments, services, ingress, secrets)
├── terraform/           # Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/         # VPC + subnets + NAT gateway
│   │   ├── eks/         # EKS cluster + node group
│   │   ├── alb_controller/ # AWS Load Balancer Controller (IRSA)
│   │   └── argocd/      # ArgoCD Helm install
│   ├── main.tf
│   ├── variables.tf
│   ├── providers.tf
│   └── terraform.tfvars
└── Jenkinsfile_eks      # Full CI pipeline definition
```

---

## ⚙️ Environment Setup

> `.env` files are **not committed**. Create `backend/.env` manually before running locally.

### 📄 `backend/.env`

```env
PORT=4000
JWT_SECRET=your_strong_random_secret_here
SALT=10
MONGO_URL=mongodb+srv://<user>:<password>@<cluster>.mongodb.net/?appName=food-app
STRIPE_SECRET_KEY=sk_live_your_stripe_live_key
FRONTEND_URL=http://<ALB_DNS>
```

> `VITE_BACKEND_URL=/api` is passed as a Docker `--build-arg` by Jenkins — no `.env` file needed for frontend or admin.

---

### 🔐 `k8s_eks/backend-secret.yaml`

This file is gitignored — **never commit real values**. Fill in your values and keep it local.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
type: Opaque
stringData:
  PORT: "4000"
  JWT_SECRET: ""
  SALT: ""
  MONGO_URL: ""
  STRIPE_SECRET_KEY: ""
  FRONTEND_URL: ""
```

---

## 🚀 Deployment — Step by Step

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform
- kubectl
- Helm
- Docker
- Jenkins server (with SonarQube, OWASP DC, Trivy installed)

---

### ⚙️ Jenkins Server Setup (Ansible)

All required tools on the Jenkins server are installed automatically using Ansible.

```bash
cd ansible-devops
ansible-playbook site.yml --ask-become-pass
```

This installs the following on your Ubuntu 24.04 Jenkins server:

| Tool | Role |
|---|---|
| Docker + Compose | Build and push images |
| Jenkins LTS | CI pipeline |
| kubectl | Interact with EKS |
| Terraform | Provision infrastructure |
| AWS CLI | AWS authentication |


### Step 1 — Provision Infrastructure (Terraform)

> Three-step apply is required on first run — VPC must exist before EKS, and EKS must exist before the Kubernetes/Helm providers can initialise for ALB Controller and ArgoCD.

```bash
cd terraform

terraform init

terraform apply -target=module.vpc

terraform apply -target=module.eks

# Now deploy ALB Controller + ArgoCD
terraform apply
```

---

### Step 2 — Configure kubectl

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name food-delivery-cluster
```

---

### Step 3 — Create the Kubernetes Secret

Fill in `k8s_eks/backend-secret.yaml` with your real values, then **push it to your K8s manifest repo** — ArgoCD needs it in the repo to apply it to the cluster.

```bash
# After filling in the values:
git add k8s_eks/backend-secret.yaml
git commit -m "add backend secret"
git push
```

> Make sure `backend-secret.yaml` is in your **K8s manifest repo**, not your app code repo.

---

### Step 4 — Connect ArgoCD to your K8s manifest repo

```bash
# Get ArgoCD initial admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then in the ArgoCD UI, create an Application pointing to your K8s manifest repo. ArgoCD will sync and apply **all manifests** — deployments, services, ingress, and the backend secret.

---

### Step 5 — First Manual Sync with ArgoCD

In the ArgoCD UI, click **Sync** manually on your Application for the first time. ArgoCD will apply all manifests — deployments, services, ingress, and the backend secret — to the cluster. AWS will provision the ALB from the Ingress automatically.

```bash
# Once synced, grab the ALB DNS
kubectl get ingress
# Copy the value in the ADDRESS column

# Update FRONTEND_URL in backend-secret.yaml with the ALB DNS, then:
kubectl apply -f k8s_eks/backend-secret.yaml
kubectl rollout restart deployment/backend-deployment
```

---

### Step 6 — Run the Jenkins Pipeline

Trigger `Jenkinsfile_eks` — it will:
1. Checkout source code
2. Run SonarQube analysis (backend, frontend, admin — parallel)
3. Run OWASP Dependency-Check (parallel)
4. Quality Gate check
5. Trivy filesystem scan
6. Build Docker images
7. Trivy image scan per image
8. Push images to Docker Hub
9. Update image tags in the K8s manifest repo

---

### Step 7 — ArgoCD Detects Changes & Deploys

ArgoCD detects the image tag update pushed by Jenkins and auto-syncs — rolling out the new pods on EKS automatically. No manual action needed from this point on.

---

### Webhooks (Recommended)

Set up webhooks so Jenkins triggers on every push and ArgoCD syncs instantly instead of polling.

**GitHub → Jenkins**
- URL: `http://<jenkins-ip>:8080/github-webhook/`
- In Jenkins job → Build Triggers → enable **GitHub hook trigger for GITScm polling**

**GitHub → ArgoCD**
- URL: `http://<argocd-ip>/api/webhook`
- Then add the secret in the cluster:

```bash
kubectl edit secret argocd-secret -n argocd
# Add under stringData:
#   webhook.github.secret: mysecret123
```

---

## 🔑 Jenkins Credentials Required

Configure these in **Jenkins → Manage Credentials**:

| Credential ID | Type | Used for |
|---|---|---|
| `github-credentials` | Username / Password | Git checkout + manifest push |
| `dockerhub-credentials` | Username / Password | Docker login |
| `NVD_API_KEY` | Secret text | OWASP Dependency-Check |
| `sonar-token` | Secret text | SonarQube quality gate |


## 🧩 Jenkins Plugin required
install these plugins in **Jenkins**
- stage view 
- Docker
- Docker Commons
- Docker Pipeline
- Docker API
- docker-build-step
- Eclipse Temurin installer
- NodeJS
- OWASP Dependency-Check
- SonarQube Scanner

## 🔑 Jenkins Setup

### Manage Jenkins → System
- Add SonarQube server:
  - Name: `sonar-server`
  - URL: `http://<sonarqube-ip>:9000`
  - Token: use `sonar-token` credential

---

### Manage Jenkins → Tools

| Tool | Name to set |
|---|---|
| JDK | `jdk` |
| NodeJS | `nodejs` |
| SonarQube Scanner | `sonar-scanner` |
| OWASP Dependency-Check | `DP-Check` |

> These names must match exactly — the Jenkinsfile references them directly.

---

### Manage Jenkins → Credentials

| Credential ID | Type | What to put |
|---|---|---|
| `github-credentials` | Username / Password | Your GitHub username + Personal Access Token |
| `dockerhub-credentials` | Username / Password | Your Docker Hub username + password |
| `NVD_API_KEY` | Secret text | Your NVD API key (get it from nvd.nist.gov) |
| `sonar-token` | Secret text | Token from SonarQube → My Account → Security |

---

### Jenkinsfile — update these before running

```groovy
APP_REPO       = 'https://github.com/<your-username>/<your-app-repo>.git'
K8S_REPO_NAME  = '<your-k8s-manifest-repo-name>'
DOCKERHUB_USER = '<your-dockerhub-username>'
```

Also update the clone and push URLs in Stage 9:

```groovy
git clone https://\$GIT_USER:\$GIT_PASS@github.com/<your-username>/<your-k8s-repo>.git
git push  https://\$GIT_USER:\$GIT_PASS@github.com/<your-username>/<your-k8s-repo>.git main
```
---

## 🔐 Security

- All secrets are injected into pods via Kubernetes Secrets — nothing is baked into images.
- Trivy scans both the filesystem and each built Docker image before push.
- OWASP Dependency-Check scans all three apps for known CVEs.
- SonarQube analyses backend, frontend, and admin for vulnerabilities and code smells.


---
