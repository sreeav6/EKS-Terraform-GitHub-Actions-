# SimpleTimeService

A minimal Python/Flask microservice that returns the current UTC timestamp and the visitor's IP address as JSON. Containerised with Docker and deployed to AWS EKS using Terraform.

```json
{
  "timestamp": "2024-01-15T10:30:00.123456+00:00",
  "ip": "203.0.113.42"
}
```

---

## Repository structure

```
.
├── app/                              # Application source and Dockerfile
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
├── .github/
│   └── workflows/
│       ├── docker.yml                # Build and push image on app/ changes
│       └── terraform.yml             # Plan on PR, apply on merge to main
└── terraform/                        # Run terraform plan/apply from here
    ├── versions.tf                   # Provider versions + S3 backend
    ├── providers.tf                  # AWS, Kubernetes, Helm provider config
    ├── variables.tf                  # Input variable declarations
    ├── outputs.tf                    # Post-apply useful values
    ├── terraform.tfvars              # Default variable values
    ├── main.tf                       # Wires the four modules together
    ├── bootstrap/                    # One-time S3 + DynamoDB state backend setup
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── modules/
        ├── networking/               # VPC, public & private subnets, NAT Gateway
        ├── eks-cluster/              # EKS Auto Mode cluster
        ├── lb-controller/            # AWS Load Balancer Controller (IRSA + Helm)
        └── k8s-app/                  # Namespace, Deployment, Service, ALB Ingress
```

---

## Architecture

```
Internet
    │
    ▼
[Application Load Balancer]        ← public subnets  (10.0.1.0/24, 10.0.2.0/24)
    │
    ▼
[EKS Pods – SimpleTimeService ×2]  ← private subnets (10.0.10.0/24, 10.0.11.0/24)
    │
    ▼
[NAT Gateway]  →  Internet (outbound only — image pulls, AWS API calls)
```

### Architecture decisions

| Decision | Reason |
|---|---|
| **EKS Auto Mode** | AWS manages node pools, scaling, and patching automatically — no Karpenter or managed node group configuration needed, keeping the Terraform footprint small. |
| **ALB Ingress** | An internet-facing Application Load Balancer in the public subnets is the standard pattern for exposing EKS workloads. The AWS Load Balancer Controller reconciles the `Ingress` object into a real ALB. |
| **Private subnets for pods** | Pods have no public IP. All inbound traffic goes through the ALB; outbound traffic goes through the NAT Gateway. |
| **Python + Flask + gunicorn** | Minimal dependencies. The multi-stage Alpine image keeps the final image under ~60 MB. |
| **S3 + DynamoDB backend** | Remote state means any team member or CI job works from the same state file. DynamoDB provides atomic locking so concurrent applies never corrupt state. |

---

## Prerequisites

| Tool | Min version | Install |
|---|---|---|
| Terraform | 1.9 | https://developer.hashicorp.com/terraform/install |
| AWS CLI | v2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| kubectl | any recent | https://kubernetes.io/docs/tasks/tools/ |
| Docker | any recent | https://docs.docker.com/get-docker/ |

---

## Part 1 — Build and publish the container image

> Skip this section if you want to use the pre-built public image
> (`docker.io/anilsree/simpletimeservice:latest`).

```bash
cd app

docker build -t <your-dockerhub-username>/simpletimeservice:latest .

# Verify the app responds correctly
docker run --rm -p 8080:8080 <your-dockerhub-username>/simpletimeservice:latest
curl http://localhost:8080/

# Push to Docker Hub
docker login
docker push <your-dockerhub-username>/simpletimeservice:latest
```

Update `container_image` in `terraform/terraform.tfvars` to point at your image before deploying.

---

## Part 2 — Deploy with Terraform

### Step 1 — Configure AWS credentials

```bash
aws configure --profile simpletimeservice
# Enter Access Key ID, Secret Access Key, and region (us-east-1)

export AWS_PROFILE=simpletimeservice
```

Or export directly:

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"
```

> The IAM identity needs permissions to create VPCs, EKS clusters, IAM roles, ALBs, and DynamoDB tables. Attaching `AdministratorAccess` is the quickest option for a demo account.

### Step 2 — Bootstrap remote state (run once)

This creates the S3 bucket and DynamoDB table that Terraform uses to store and lock state.

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

The output prints the exact bucket and table names. They are already set in `terraform/versions.tf` — update them there if you change the defaults in `bootstrap/variables.tf`.

### Step 3 — Deploy the infrastructure

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

`terraform apply` takes roughly **15–20 minutes** — most of that is EKS control plane provisioning.

### Step 4 — Access the application

After apply completes, Terraform prints:

```
cluster_name      = "simpletimeservice-cluster"
configure_kubectl = "aws eks update-kubeconfig --region us-east-1 --name simpletimeservice-cluster"
app_url           = "http://<alb-hostname>"
```

The ALB needs 2–3 minutes after apply to pass health checks. If `app_url` is not yet available, run `terraform refresh`.

```bash
curl http://<alb-hostname>
# {"ip":"203.0.113.42","timestamp":"2024-01-15T10:30:00.123456+00:00"}
```

### Step 5 — (Optional) Connect kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name simpletimeservice-cluster
kubectl get pods -n simpletimeservice
```

### Step 6 — Tear down

```bash
terraform destroy
```

---

## Remote state and locking

Terraform state is stored in **S3** and locked via **DynamoDB**.

```
terraform plan / apply / destroy
       │
       ├─► DynamoDB  write LockID   ← blocks any parallel run immediately
       ├─► S3        read state
       ├─►           make changes
       ├─► S3        write new state
       └─► DynamoDB  delete LockID  ← lock released
```

If a run is interrupted and the lock is not released automatically:

```bash
terraform force-unlock <LOCK_ID>
# LOCK_ID is printed in the error message when a lock is detected
```

After adding the backend for the first time, re-initialise and migrate any existing local state:

```bash
terraform init -migrate-state
```

> **S3 bucket names are globally unique.** If `simpletimeservice-tf-state` is taken, change `state_bucket_name` in `terraform/bootstrap/variables.tf` and update the `bucket` field in `terraform/versions.tf` to match.

---

## CI/CD with GitHub Actions

Two workflows are included in `.github/workflows/`:

### `docker.yml` — image build and push

Triggers on any push to `main` that changes a file under `app/`.

| Step | What it does |
|---|---|
| Build | Multi-stage Docker build using Buildx with GHA layer cache |
| Tag | Tags the image with both `:latest` and `:<git-sha>` |
| Push | Pushes both tags to Docker Hub |

### `terraform.yml` — infrastructure plan and apply

| Event | Job | What it does |
|---|---|---|
| Pull request → `main` | `plan` | Runs `terraform init` + `validate` + `plan`, posts the full plan output as a collapsible PR comment |
| Push to `main` | `apply` | Runs `terraform init` + `apply -auto-approve`, prints outputs |

The `apply` job targets the `production` GitHub environment — enable required reviewers on that environment in **Settings → Environments** to add a manual approval gate before production changes are applied.

### Required GitHub secrets

Add these under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key with permissions to manage the stack |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret key |
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token (create at hub.docker.com → Account Settings → Security) |

---

## Module reference

### `modules/networking`
Creates a VPC with two public and two private subnets across two AZs, plus a single NAT Gateway.

### `modules/eks-cluster`
Provisions an EKS Auto Mode cluster in the private subnets. Includes a 30-second wait after cluster creation before any Kubernetes API calls are made.

### `modules/lb-controller`
Creates an IRSA IAM role and installs the AWS Load Balancer Controller Helm chart into `kube-system`. This controller watches for `Ingress` objects and provisions AWS ALBs.

### `modules/k8s-app`
Deploys the application: `Namespace`, `Deployment` (with liveness/readiness probes and resource limits), `ClusterIP` `Service`, and an `Ingress` that the Load Balancer Controller turns into an internet-facing ALB.

---

## Security notes

- Pods run as a **non-root user** (`appuser`) inside the container.
- Pods are in **private subnets** with no public IP.
- All inbound traffic goes through the **ALB in the public subnets**.
- The Load Balancer Controller uses **IRSA** — no long-lived credentials stored in the cluster.
- `terraform.tfvars` contains no secrets and is safe to commit.
- Never commit `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` — pass them via environment variables or GitHub secrets only.
