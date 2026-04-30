# Laravel Booking Application

A simple REST API built with Laravel demonstrating production-grade containerization, CI/CD pipeline configuration, and Infrastructure as Code using Terraform on **Microsoft Azure**.

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

---

## Quick Start

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- [Git](https://git-scm.com/)

### 1. Clone the repository

```bash
git clone https://github.com/kena-b-y/laravel-booking.git
cd laravel-booking
```

### 2. Set up environment variables

```bash
cp .env.example .env
```

Open `.env` and set:

```env
APP_KEY=base64:YOUR_GENERATED_KEY
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=booking_db
DB_USERNAME=root
DB_PASSWORD=
```

Generate a fresh `APP_KEY`:

```bash
# If PHP is installed locally:
php artisan key:generate --show

# Or after the containers start:
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
docker compose down -v     # stop containers and wipe database volume
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
                         ┌──────────────────────────────────────────────────────────┐
                         │                    Azure Subscription                    │
                         │                                                          │
                         │  ┌───────────────────────────────────────────────────┐   │
                         │  │              Resource Group                        │   │
                         │  │                                                   │   │
  ┌──────────┐  HTTPS    │  │  ┌─────────────────────────────────────────────┐  │   │
  │  Client  │ ────────► │  │  │             Virtual Network (VNet)          │  │   │
  └──────────┘           │  │  │                                             │  │   │
                         │  │  │  ┌─────────────────┐  ┌──────────────────┐  │  │   │
                         │  │  │  │  Container subnet│  │   DB subnet      │  │  │   │
  ┌──────────────────┐   │  │  │  │  (private)       │  │   (private)      │  │  │   │
  │  GitHub Actions  │   │  │  │  │                  │  │                  │  │  │   │
  │  CI/CD Pipeline  │   │  │  │  │ ┌──────────────┐ │  │ ┌────────────┐  │  │  │   │
  │                  │   │  │  │  │ │Azure Container│ │  │ │  Azure DB  │  │  │  │   │
  │ 1. Lint & test   │   │  │  │  │ │     Apps      │ │  │ │  for MySQL │  │  │  │   │
  │ 2. Build image   │   │  │  │  │ │               │◄├──┼─┤ Flexible   │  │  │  │   │
  │ 3. Push to ACR   │   │  │  │  │ │  Laravel app  │ │  │ │  Server    │  │  │  │   │
  │ 4. Manual approve│   │  │  │  │ │  (replicas)   │ │  │ └────────────┘  │  │  │   │
  │ 5. TF apply      │   │  │  │  │ └──────┬────────┘ │  └──────────────────┘  │  │   │
  │ 6. Rollback      │   │  │  │  └─────────┼──────────┘                       │  │   │
  └──────┬───────────┘   │  │  │            │ Built-in HTTPS ingress            │  │   │
         │               │  │  └────────────┼─────────────────────────────────┘  │   │
         │               │  │               │                                     │   │
         │               │  │  ┌────────────▼──────┐  ┌─────────────────────┐    │   │
         └──────────────►│  │  │  Azure Container   │  │   Azure Key Vault   │    │   │
           push image    │  │  │  Registry (ACR)    │  │                     │    │   │
                         │  │  │  (image storage)   │  │  - db-password      │    │   │
                         │  │  └────────────────────┘  │  - app-key          │    │   │
                         │  │                           └─────────────────────┘    │   │
                         │  │  ┌────────────────────┐                              │   │
                         │  │  │  Managed Identity   │ ── AcrPull ──► ACR         │   │
                         │  │  │  (no credentials)   │ ── KV Secrets User ──► KV  │   │
                         │  │  └────────────────────┘                              │   │
                         │  └───────────────────────────────────────────────────┘   │
                         └──────────────────────────────────────────────────────────┘


Local Development (docker compose up):

  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │  ┌──────────────┐    ┌──────────┐    ┌───────────┐   │
  │  │ Nginx        │───►│ PHP-FPM  │───►│  MySQL 8  │   │
  │  │ :8000        │    │  (app)   │    │  :3307    │   │
  │  └──────────────┘    └──────────┘    └───────────┘   │
  │                                                      │
  └──────────────────────────────────────────────────────┘
```

---

## CI/CD Pipeline

The pipeline is defined in `.github/workflows/deploy.yml` and runs on GitHub Actions.

### GitHub Secrets required

Add these in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | Service Principal app ID (has AcrPush + Terraform roles) |
| `AZURE_CLIENT_SECRET` | Service Principal secret |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `AZURE_TENANT_ID` | Your Azure Active Directory tenant ID |
| `AZURE_CREDENTIALS` | Full JSON credentials blob for `azure/login` action |
| `DB_PASSWORD` | MySQL password (written to Key Vault by Terraform) |
| `APP_KEY` | Laravel APP_KEY (written to Key Vault by Terraform) |

### Pipeline stages

#### Stage 1 — Lint and test (every pull request)

Installs PHP dependencies, sets up an in-memory SQLite database, and runs the full PHPUnit test suite plus a PHP syntax check across the `app/` directory. A failing test blocks the PR from being merged.

**Why:** Catching bugs before they reach `main` keeps the branch always deployable. SQLite in-memory means no external database is needed in CI — tests run fast and in isolation.

#### Stage 2 — Build and push Docker image (push to main)

Builds the production Docker image and tags it with the first 7 characters of the git commit SHA. Pushes both the SHA tag and `latest` to Azure Container Registry.

**Why:** The SHA tag creates an immutable, traceable artifact. You can always identify exactly which commit is running in production. The image is built once and promoted through environments — never rebuilt.

#### Stage 3 — Terraform plan

Authenticates to Azure, initialises the Terraform backend (Azure Blob Storage), and runs `terraform plan` with the new image tag. The plan output shows exactly what infrastructure changes will be made. The plan file is saved as a GitHub Actions artifact so Stage 5 applies the exact same plan that was reviewed.

**Why:** Separating plan from apply means there are no surprises during the deploy. The reviewer sees precisely what will change before approving.

#### Stage 4 — Manual approval gate

The pipeline pauses and waits for a human to approve in the GitHub Actions UI. This is implemented using a GitHub Environment (`production`) with required reviewers configured.

**Why:** No code reaches production without explicit sign-off. Critical for catching issues like missed database migrations or breaking API changes that tests didn't catch.

#### Stage 5 — Deploy

Applies the pre-approved Terraform plan (not a fresh plan — the same saved artifact). Container Apps uses `revision_mode = "Multiple"` which starts the new revision before deactivating the old one — zero downtime rolling deployment. A health check loop verifies the app is responding before the job completes.

**Why:** Applying the reviewed plan (not a new one) prevents race conditions where the infrastructure changes between plan and apply. The post-deploy health check gives early warning if the deployment is broken.

#### Stage 6 — Rollback

Manually triggered via `workflow_dispatch` with a `rollback_tag` input (a previous git SHA). Reruns Terraform with the old image tag — no rebuild needed because the old image is still in ACR. Requires production environment approval before executing.

**Why:** Recovery from a bad deploy is a one-click operation, not a manual emergency process. Since images are never deleted from ACR, any previous version can be redeployed instantly.

---

## Infrastructure as Code

All Azure infrastructure is defined in the `terraform/` directory using the `azurerm` provider. No credentials or resource-specific values are hardcoded — everything is parameterised via variables.

### Resources provisioned

| File | What it creates |
|---|---|
| `main.tf` | Provider config, remote backend (Azure Blob Storage), Resource Group |
| `variables.tf` | All input variables with descriptions and types |
| `vnet.tf` | Virtual Network, private subnets (containers + DB), NSGs, private DNS zone |
| `acr.tf` | Azure Container Registry (Standard tier, admin disabled) |
| `mysql.tf` | MySQL Flexible Server in private subnet, application database |
| `aca.tf` | Container Apps Environment, Container App with scaling rules, ingress, probes |
| `rbac.tf` | Managed Identity, AcrPull role, Key Vault Secrets User role, CI push role |
| `keyvault.tf` | Key Vault with RBAC auth, soft-delete, network ACLs, app secrets |
| `outputs.tf` | App URL, ACR server, Key Vault URI, MySQL FQDN |

### Identity and access approach

The Container App uses a **User-Assigned Managed Identity** — the Azure equivalent of an IAM instance role. It has exactly two permissions:

- `AcrPull` on this specific ACR — can pull images, nothing else
- `Key Vault Secrets User` on this specific Key Vault — can read secret values, nothing else

No wildcard permissions (`*`) exist anywhere. No passwords or credentials are stored in the Container App configuration — secrets are Key Vault references, fetched by the platform at container startup.

### Secrets handling

Secrets flow: GitHub secrets → Terraform variables → Azure Key Vault → Container App environment variables (injected at runtime by the platform).

The raw secret value is never stored in Terraform state in plaintext (variables marked `sensitive = true`), never in source control, and never visible in Azure portal Container App configuration — only the Key Vault reference URI is stored there.

### Reviewing the Terraform without an Azure account

```bash
cd terraform
terraform init -backend=false
terraform validate
terraform plan -var="image_tag=abc1234" -var="db_password=example" -var="app_key=base64:example"
```

---

## Project Structure

```
laravel-booking/
├── app/
│   └── Http/Controllers/Api/
│       └── BookingController.php       # POST /bookings, GET /bookings/{id}
├── database/migrations/
│   └── xxxx_create_bookings_table.php
├── routes/
│   └── api.php                         # Route definitions
├── nginx/
│   └── default.conf                    # Nginx reverse proxy config
├── Dockerfile                          # Multi-stage production image
├── docker-compose.yml                  # Local dev: app + webserver + db
├── .env.example                        # Template — never commit .env
├── .github/
│   └── workflows/
│       └── deploy.yml                  # GitHub Actions CI/CD (Azure)
└── terraform/
    ├── main.tf                         # Provider, backend, resource group
    ├── variables.tf                    # All input variables
    ├── vnet.tf                         # VNet, subnets, NSGs, DNS
    ├── acr.tf                          # Azure Container Registry
    ├── mysql.tf                        # MySQL Flexible Server
    ├── aca.tf                          # Azure Container Apps
    ├── rbac.tf                         # Managed Identity, role assignments
    ├── keyvault.tf                     # Key Vault, secrets
    └── outputs.tf                      # App URL, ACR server, etc.
```

---

## Assumptions

1. **Azure over AWS.** The assessment accepts either cloud. Azure was chosen and the entire stack is Azure-native: ACR, Azure Container Apps, Azure Database for MySQL, Key Vault, and Managed Identity.

2. **Azure Container Apps over AKS.** Container Apps is the serverless container platform — the equivalent of ECS Fargate. AKS (full Kubernetes) would be overkill for a two-endpoint API and would require significantly more operational overhead. Container Apps includes built-in ingress, scaling, and rolling deployments at no extra configuration cost.

3. **Terraform over Azure Bicep.** The assessment accepts either. Terraform was chosen because it is cloud-agnostic, widely used in industry, and the `azurerm` provider covers all required Azure resources fully.

4. **User-Assigned Managed Identity over Service Principal credentials.** Managed Identity means zero credentials to rotate or store. The Container App authenticates to ACR and Key Vault without any password.

5. **Single region deployment.** All resources are in one Azure region. A production setup would consider paired regions and geo-redundant database backups, but this adds significant complexity and cost for an assessment.

6. **Migrations run manually on first deploy.** `php artisan migrate` must be run once inside the container after the first deployment. Automating this safely in CI requires a dedicated pre-deploy job with its own approval gate — left out to keep the pipeline readable.

7. **No custom domain or TLS certificate.** Container Apps provides a default HTTPS endpoint (`*.azurecontainerapps.io`). A custom domain with an Azure-managed certificate would require a registered domain name.
