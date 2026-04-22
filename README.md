# Laravel Booking Application

A simple REST API built with Laravel that demonstrates production-grade containerization, CI/CD pipeline configuration, and Infrastructure as Code using Terraform on AWS.

> **Assessment note:** The application itself is intentionally minimal — two booking endpoints and a health check. The focus of this project is the infrastructure, containerization, and deployment configuration surrounding it.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Application Endpoints](#application-endpoints)
- [Architecture Diagram](#architecture-diagram)
- [CI/CD Pipeline](#cicd-pipeline)
- [Infrastructure as Code](#infrastructure-as-code)
- [Project Structure](#project-structure)
- [Assumptions](#assumptions)
- [What I Would Improve With More Time](#what-i-would-improve-with-more-time)

---

## Quick Start

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- [Git](https://git-scm.com/)

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/laravel-booking.git
cd laravel-booking
```

### 2. Set up environment variables

```bash
cp .env.example .env
```

Open `.env` and confirm these values match `docker-compose.yml`:

```env
APP_KEY=base64:YOUR_GENERATED_KEY
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=booking_db
DB_USERNAME=laravel
DB_PASSWORD=secret
```

Generate a fresh `APP_KEY`:

```bash
# If you have PHP installed locally:
php artisan key:generate --show

# Or generate one inside Docker after first boot:
docker compose exec app php artisan key:generate
```

### 3. Start the full environment

```bash
docker compose up --build
```

This single command starts three services:

| Service | Description | Port |
|---|---|---|
| `app` | PHP-FPM running the Laravel application | Internal (9000) |
| `webserver` | Nginx reverse proxy | `localhost:8000` |
| `db` | MySQL 8 database | `localhost:3307` |

### 4. Run database migrations

In a second terminal:

```bash
docker compose exec app php artisan migrate
```

### 5. Verify everything is working

```bash
# Health check
curl http://localhost:8000/api/health

# Create a booking
curl -X POST http://localhost:8000/api/bookings \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe","email":"jane@example.com","booking_date":"2025-06-01"}'

# Retrieve a booking
curl http://localhost:8000/api/bookings/1
```

### Stopping the environment

```bash
docker compose down        # stop containers
docker compose down -v     # stop containers and delete database volume
```

---

## Application Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | Health check — returns `{"status":"ok"}` |
| `POST` | `/api/bookings` | Create a new booking |
| `GET` | `/api/bookings/{id}` | Retrieve a booking by ID |

### POST /api/bookings — Request body

```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "booking_date": "2025-06-01"
}
```

### POST /api/bookings — Response (201 Created)

```json
{
  "id": 1,
  "name": "Jane Doe",
  "email": "jane@example.com",
  "booking_date": "2025-06-01",
  "status": "pending",
  "created_at": "2025-04-22T08:00:00.000000Z",
  "updated_at": "2025-04-22T08:00:00.000000Z"
}
```

---

## Architecture Diagram

```
                          ┌─────────────────────────────────────────────┐
                          │                  AWS VPC                     │
                          │                                              │
  ┌──────────┐   HTTPS    │  ┌────────────┐        ┌──────────────────┐ │
  │  Client  │ ─────────► │  │    ALB     │ ──────► │  ECS Fargate     │ │
  └──────────┘            │  │ (public    │        │  (private subnet) │ │
                          │  │  subnet)   │        │                  │ │
                          │  └────────────┘        │  ┌────────────┐  │ │
                          │                        │  │  Laravel   │  │ │
  ┌──────────────────┐    │  ┌────────────┐        │  │  Container │  │ │
  │   GitHub Actions │    │  │    NAT     │        │  └─────┬──────┘  │ │
  │   CI/CD Pipeline │    │  │  Gateway   │        └────────┼─────────┘ │
  │                  │    │  │ (public    │                 │           │
  │  1. Test         │    │  │  subnet)   │        ┌────────▼─────────┐ │
  │  2. Build image  │    │  └────────────┘        │  RDS MySQL       │ │
  │  3. Push to ECR  │    │                        │  (private subnet) │ │
  │  4. Approve      │    └─────────────────────────────────────────────┘
  │  5. Deploy/      │
  │     Rollback     │    ┌─────────────┐    ┌──────────────────────────┐
  └──────┬───────────┘    │     ECR     │    │     Secrets Manager      │
         │                │  (container │    │  - DB password           │
         └──────────────► │   registry) │    │  - APP_KEY               │
                          └─────────────┘    └──────────────────────────┘


Local Development:

  ┌─────────────────────────────────────────────────┐
  │  docker compose up                              │
  │                                                 │
  │  ┌──────────┐    ┌──────────┐    ┌───────────┐  │
  │  │  Nginx   │───►│  PHP-FPM │───►│  MySQL 8  │  │
  │  │ :8000    │    │  (app)   │    │  :3307    │  │
  │  └──────────┘    └──────────┘    └───────────┘  │
  └─────────────────────────────────────────────────┘
```

---

## CI/CD Pipeline

The pipeline is defined in `.github/workflows/deploy.yml` and runs on GitHub Actions.

### Pipeline stages

#### Stage 1 — Lint and test (runs on every pull request)

Triggered on every PR to `main`. Installs PHP dependencies, sets up an in-memory SQLite database, and runs the full PHPUnit test suite. A failing test blocks the PR from being merged.

**Why:** Catching bugs before they reach main protects the team and keeps the main branch always deployable.

#### Stage 2 — Build Docker image

Runs on push to `main` after tests pass. Builds the Docker image using the production Dockerfile (multi-stage, Alpine-based) and tags it with the exact git commit SHA.

**Why:** Tagging with the commit SHA creates an immutable, traceable artifact. You can always trace any running container back to the exact line of code that built it.

#### Stage 3 — Push to container registry

Authenticates to Amazon ECR using short-lived OIDC credentials (no long-lived keys stored in GitHub secrets) and pushes the tagged image.

**Why:** ECR is private, versioned, and co-located with ECS. Images are scanned for vulnerabilities on push.

#### Stage 4 — Manual approval gate

The workflow pauses before any production deployment and waits for a human to approve it via the GitHub Actions UI. No code reaches production without an explicit sign-off.

**Why:** Prevents automated deployments from silently breaking production. Especially important for database migrations or breaking API changes.

#### Stage 5 — Deploy (or rollback)

On approval, Terraform applies the updated infrastructure (new ECS task definition pointing at the new image tag). ECS performs a rolling deploy — new containers pass ALB health checks before old ones are drained.

A separate `rollback` job can be manually triggered. It redeploys the previous image tag by passing the last known-good SHA as a Terraform variable, which updates the ECS task definition back to that image.

**Why:** Rolling deploys give zero downtime. The rollback step means recovery from a bad deploy is a single button press, not a manual process.

---

## Infrastructure as Code

All AWS infrastructure is defined in the `terraform/` directory. No resources are hardcoded — everything is parameterised via variables.

### Resources provisioned

| File | What it creates |
|---|---|
| `vpc.tf` | VPC, public subnets (ALB, NAT), private subnets (ECS, RDS) |
| `ecr.tf` | Private container registry with vulnerability scanning |
| `rds.tf` | MySQL 8 on `db.t3.micro`, in the private subnet, no public access |
| `ecs.tf` | Fargate cluster, task definition, service with rolling deploy config |
| `alb.tf` | Application Load Balancer, target group, health check listener |
| `iam.tf` | ECS task execution role with least-privilege permissions |
| `secrets.tf` | Secrets Manager entries for DB password and APP_KEY |

### IAM approach

The ECS task execution role has only two permissions:

1. The AWS-managed `AmazonECSTaskExecutionRolePolicy` (pull from ECR, write to CloudWatch Logs)
2. A custom inline policy scoped to only the two specific Secrets Manager ARNs the app needs

No wildcards (`*`) on resources or actions anywhere.

### Secrets handling

Secrets are never in environment variables, `.env` files, or Terraform state in plaintext. They are stored in AWS Secrets Manager and injected into the ECS container at runtime by the ECS agent. The application reads them as standard environment variables — no code changes needed.

### Running Terraform locally (review only — no account needed)

```bash
cd terraform
terraform init
terraform plan -var="image_tag=abc123" -var="db_password=example"
```

---

## Project Structure

```
laravel-booking/
├── app/
│   └── Http/Controllers/Api/
│       └── BookingController.php    # POST /bookings, GET /bookings/{id}
├── database/migrations/
│   └── xxxx_create_bookings_table.php
├── routes/
│   └── api.php                      # Route definitions
├── docker/
│   ├── nginx.conf                   # Nginx config (single-container mode)
│   └── supervisord.conf             # Supervisor config (nginx + php-fpm)
├── nginx/
│   └── default.conf                 # Nginx config (separate webserver container)
├── Dockerfile                       # Multi-stage production image
├── docker-compose.yml               # Local dev: app + webserver + db
├── .env.example                     # Template — never commit .env
├── .github/
│   └── workflows/
│       └── deploy.yml               # GitHub Actions CI/CD pipeline
├── terraform/
│   ├── main.tf                      # Provider, backend config
│   ├── variables.tf                 # All input variables
│   ├── vpc.tf                       # Networking
│   ├── ecr.tf                       # Container registry
│   ├── rds.tf                       # Database
│   ├── ecs.tf                       # Compute (Fargate)
│   ├── alb.tf                       # Load balancer
│   ├── iam.tf                       # Roles and policies
│   ├── secrets.tf                   # Secrets Manager
│   └── outputs.tf                   # ALB URL, ECR URL, RDS endpoint
└── README.md
```

---

## Assumptions

1. **AWS as the target cloud.** The assessment mentioned AWS, ECR, and ECS as examples — the entire IaC is AWS-native. The same patterns apply to Azure (AKS + ACR + Bicep) with minor translation.

2. **Fargate over EC2.** I chose ECS Fargate rather than raw EC2 to avoid managing the underlying instances. For a containerised workload this is the right default — you pay per task, not per idle server.

3. **Single NAT gateway in dev.** `single_nat_gateway = true` on the VPC module reduces cost significantly in non-production. Production should use one NAT gateway per availability zone for resilience.

4. **MySQL over PostgreSQL.** Laravel works equally well with either. MySQL 8 was chosen because it is the most common default in Laravel projects.

5. **No HTTPS in the base config.** The ALB listener is HTTP on port 80. Adding HTTPS requires an ACM certificate, which requires a domain name — left out to keep the config runnable without a registered domain.

6. **Migrations run manually on first deploy.** The pipeline does not auto-run `php artisan migrate`. This is intentional — running migrations automatically in CI on a production database is risky. In a mature setup this would be a separate, gated pipeline step.

7. **`desired_count = 2` on the ECS service.** Two tasks gives basic high availability across two availability zones without significant cost increase.

---

## What I Would Improve With More Time

**1. HTTPS with ACM and Route 53**
The current setup serves traffic over plain HTTP. In production I would provision an ACM certificate, add an HTTPS listener on port 443 to the ALB, and redirect HTTP to HTTPS. This requires a registered domain but is straightforward with Terraform's `aws_acm_certificate` and `aws_route53_record` resources.

**2. Automated database migrations in the pipeline**
Right now migrations must be run manually inside a container. The better approach is a dedicated ECS task that runs `php artisan migrate --force` as a pre-deploy step in the pipeline, gated behind the same approval step as the main deploy. This makes deploys fully automated and auditable.

**3. Autoscaling on the ECS service**
The current config runs a fixed two tasks. Adding an `aws_appautoscaling_target` and `aws_appautoscaling_policy` based on ALB request count or CPU utilisation would let the service handle traffic spikes without manual intervention.

**4. Terraform workspaces or separate state per environment**
Currently there is one Terraform state file. A production setup would use separate state files (or Terraform workspaces) for `dev`, `staging`, and `production`, each with different variable values and potentially different AWS accounts.

**5. Vulnerability scanning in the pipeline**
ECR scans images on push, but the pipeline does not gate on the results. Adding a step that calls `aws ecr describe-image-scan-findings` and fails the build on critical CVEs would prevent known-vulnerable images from being deployed.
