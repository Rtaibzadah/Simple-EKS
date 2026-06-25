# Simple-EKS

Kubernetes platform on AWS EKS. Fully automated from infrastructure provisioning to application deployment, built with Terraform, Helm, GitHub Actions, ArgoCD, and Prometheus.

---

## Features

- Terraform-provisioned AWS infrastructure
- Containerised application deployed to EKS
- HTTPS with automated TLS via Let's Encrypt
- Automated DNS management via ExternalDNS and Route53
- CI/CD Pipeline 1 — Terraform plan and apply on push
- CI/CD Pipeline 2 — Docker build, Trivy vulnerability scan, ECR push, rolling deploy
- GitOps with ArgoCD — auto-sync on every commit
- Cluster observability with Prometheus and Grafana
---

## Architecture

<img width="972" height="619" alt="Screenshot 2026-06-25 at 15 27 14" src="https://github.com/user-attachments/assets/6fb946d6-2d28-469e-ac33-87a41b40e4c5" />

---

## Observability

Prometheus scrapes metrics from all cluster components. Grafana provides pre-built dashboards for CPU, memory, pod counts, and namespace-level resource usage across the entire cluster.

<img width="1470" height="831" alt="Screenshot 2026-06-25 at 15 07 28" src="https://github.com/user-attachments/assets/1453ba1f-99bf-4e47-bb7e-233b49ac3206" />


---

## GitOps — ArgoCD

ArgoCD watches the `k8s/` directory in this repository. Any committed change is automatically detected and synced to the cluster without manual intervention. The resource tree below shows the full application state — deployment, service, ingress, certificates, and pods — all managed declaratively from Git.

<img width="1470" height="830" alt="Screenshot 2026-06-25 at 14 26 14" src="https://github.com/user-attachments/assets/3014e8f6-f9f7-4799-abd6-16b43ba4a4fa" />


---

## Infrastructure

Provisioned entirely with Terraform. State stored remotely in S3.

| Resource | Detail |
|---|---|
| Cloud | AWS (eu-west-2) |
| Cluster | EKS v1.32 |
| Nodes | t3.medium x2 (auto-scaling 1-3) |
| Networking | VPC, 2 public + 2 private subnets, NAT Gateway |
| Container Registry | ECR |
| DNS | Route53 hosted zone, delegated from Cloudflare |

---

## Application

A containerised 2048 game served via NGINX, built and pushed to ECR on every commit to `main` that touches `app/`, `k8s/`, or the `dockerfile`.

<img width="1468" height="920" alt="Screenshot 2026-06-25 at 14 26 01" src="https://github.com/user-attachments/assets/2cf1dd77-056b-483f-89ae-1d8437fdf859" />

---

## HTTPS / TLS

NGINX Ingress Controller handles all inbound traffic. cert-manager issues and renews Let's Encrypt production certificates automatically. ExternalDNS creates and updates Route53 A records from Ingress annotations, no manual DNS changes required after initial setup.

---

## CI/CD Pipeline 1 — Terraform

Triggers on push or pull request to `main` when files in `terraform/` change.

| Step | Action |
|---|---|
| Init | Initialises backend and providers |
| Format Check | Fails if code is not formatted |
| Validate | Validates configuration |
| Plan | Runs on pull requests |
| Apply | Runs on merge to main |

![Terraform Pipeline](images/pipeline-terraform.png)

---

## CI/CD Pipeline 2 — Docker + Deploy

Triggers on push to `main` when `app/`, `k8s/`, or `dockerfile` change.

| Step | Action |
|---|---|
| Build | Builds Docker image tagged with Git SHA |
| Scan | Trivy scans for CRITICAL and HIGH vulnerabilities |
| Push | Pushes image to ECR |
| Deploy | Updates deployment image, waits for rollout |

![Deploy Pipeline](images/pipeline-deploy.png)

---

## Stack

| Layer | Technology |
|---|---|
| Infrastructure | Terraform, AWS EKS, VPC, ECR, Route53 |
| Container Orchestration | Kubernetes, Helm |
| Ingress | NGINX Ingress Controller |
| TLS | cert-manager, Let's Encrypt |
| DNS | ExternalDNS, Route53 |
| GitOps | ArgoCD |
| CI/CD | GitHub Actions |
| Observability | Prometheus, Grafana |
| Security Scanning | Trivy |
