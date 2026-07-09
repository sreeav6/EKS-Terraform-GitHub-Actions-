# ── Namespace ─────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.project_name
  }
}

# ── Deployment ────────────────────────────────────────────────────────────────
resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.project_name
    namespace = kubernetes_namespace.app.metadata[0].name
    labels    = { app = var.project_name }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = { app = var.project_name }
    }

    template {
      metadata {
        labels = { app = var.project_name }
      }

      spec {
        container {
          name  = var.project_name
          image = var.container_image

          port {
            container_port = var.container_port
          }

          # Liveness probe — restarts the pod if the app stops responding.
          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          # Readiness probe — keeps the pod out of rotation until it is ready.
          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          # Resource requests let the scheduler place pods intelligently;
          # limits prevent a single pod from starving neighbours.
          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.app]
}

# ── Service (ClusterIP) ───────────────────────────────────────────────────────
resource "kubernetes_service" "app" {
  metadata {
    name      = var.project_name
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = { app = var.project_name }
    port {
      port        = 80
      target_port = var.container_port
    }
    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.app]
}

# ── Ingress (internet-facing AWS ALB) ─────────────────────────────────────────
resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = var.project_name
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/subnets"     = join(",", var.public_subnet_ids)
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.app]
}

# ── Destroy-time ALB cleanup ───────────────────────────────────────────────────
# Problem: when `terraform destroy` removes the Ingress k8s object, the AWS
# Load Balancer Controller starts deleting the real ALB asynchronously. If
# Terraform then tears down the EKS cluster before AWS finishes, the ALB and
# its security groups become orphaned and block VPC deletion.
#
# Fix: this null_resource depends_on the Ingress, so Terraform destroys IT
# first. The destroy provisioner explicitly deletes the Ingress via kubectl
# (stripping any finalizers), then polls AWS until the ALB is fully gone before
# Terraform proceeds to destroy anything else.
# ── ALB deletion wait ─────────────────────────────────────────────────────────
# All values needed at destroy-time are stored in triggers so the provisioner
# only references self.triggers.* — Terraform's destroy provisioner rule.
# $$ escapes a literal $ in the heredoc so Terraform does not try to
# interpolate shell variables like $NS as Terraform expressions.
resource "null_resource" "alb_cleanup" {
  triggers = {
    namespace    = kubernetes_namespace.app.metadata[0].name
    ingress_name = kubernetes_ingress_v1.app.metadata[0].name
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      set -euo pipefail

      NS="${self.triggers.namespace}"
      ING="${self.triggers.ingress_name}"
      CLUSTER="${self.triggers.cluster_name}"
      REGION="${self.triggers.aws_region}"

      echo "==> Updating kubeconfig for cluster $$CLUSTER"
      aws eks update-kubeconfig --region "$$REGION" --name "$$CLUSTER"

      echo "==> Removing finalizers from Ingress $$ING"
      kubectl patch ingress "$$ING" -n "$$NS" \
        --type=json \
        -p='[{"op":"replace","path":"/metadata/finalizers","value":[]}]' \
        2>/dev/null || true

      echo "==> Deleting Ingress $$ING to trigger ALB deletion"
      kubectl delete ingress "$$ING" -n "$$NS" --ignore-not-found --timeout=30s || true

      echo "==> Polling AWS until the ALB is gone (every 15 s, up to 5 min)"
      for i in $$(seq 1 20); do
        LB_COUNT=$$(aws elbv2 describe-load-balancers \
          --query "length(LoadBalancers[?Tags[?Key=='ingress.k8s.aws/stack' && Value=='$$NS/$$ING']])" \
          --output text 2>/dev/null || echo "0")
        if [ "$$LB_COUNT" -eq 0 ]; then
          echo "==> ALB deleted."
          exit 0
        fi
        echo "    ($$i/20) ALB still deleting — waiting 15 s"
        sleep 15
      done
      echo "==> ALB not fully deleted within timeout — continuing."
    BASH
  }

  depends_on = [kubernetes_ingress_v1.app]
}

# ── Namespace finalizer patch ─────────────────────────────────────────────────
# Runs after alb_cleanup. If the namespace is stuck in Terminating it clears
# its finalizers so Kubernetes can complete the deletion.
resource "null_resource" "namespace_cleanup" {
  triggers = {
    namespace    = kubernetes_namespace.app.metadata[0].name
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      set -euo pipefail

      NS="${self.triggers.namespace}"
      CLUSTER="${self.triggers.cluster_name}"
      REGION="${self.triggers.aws_region}"

      echo "==> Updating kubeconfig for cluster $$CLUSTER"
      aws eks update-kubeconfig --region "$$REGION" --name "$$CLUSTER"

      PHASE=$$(kubectl get namespace "$$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

      if [ "$$PHASE" = "Terminating" ]; then
        echo "==> Namespace stuck in Terminating — clearing finalizers"
        kubectl get namespace "$$NS" -o json \
          | python3 -c "
import sys, json
ns = json.load(sys.stdin)
ns['spec']['finalizers'] = []
print(json.dumps(ns))
" | kubectl replace --raw "/api/v1/namespaces/$$NS/finalize" -f - 2>/dev/null || true
        echo "==> Finalizers cleared."
      else
        echo "==> Namespace phase is '$$PHASE' — nothing to do."
      fi
    BASH
  }

  depends_on = [null_resource.alb_cleanup]
}
