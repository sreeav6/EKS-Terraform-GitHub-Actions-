# ── terraform.tfvars ──────────────────────────────────────────────────────────
# Override any variable defaults here before running terraform apply.
# ⚠  Do NOT add AWS credentials here — authenticate via the AWS CLI or
#    environment variables instead (see README.md).

aws_region         = "us-east-1"
project_name       = "simpletimeservice"
kubernetes_version = "1.32"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Point this at your own published image if you rebuild the app.
container_image = "docker.io/anilsree/simpletimeservice:latest"

replica_count = 2

tags = {
  Project   = "simpletimeservice"
  ManagedBy = "terraform"
  Env       = "demo"
}
