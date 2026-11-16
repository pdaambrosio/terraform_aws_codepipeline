# Terraform AWS CodePipeline

Infrastructure as code (Terraform) that provisions a continuous delivery pipeline on AWS using **AWS CodePipeline** and **AWS CodeDeploy**. The pipeline deploys a containerized Flask API to EC2 instances behind a Network Load Balancer.

When a pipeline run starts, CodePipeline pulls the source code from the configured GitHub repository. CodeDeploy then deploys it to the EC2 instances tagged with the environment name. The deployment runs the lifecycle hooks defined in `appspec.yml`, which build and start the application container with Docker Compose.

---

## Table of Contents

- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Provisioned Resources](#provisioned-resources)
- [Application](#application)
- [Deployment Lifecycle (CodeDeploy)](#deployment-lifecycle-codedeploy)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage](#usage)
- [Outputs](#outputs)
- [Running the Application Locally](#running-the-application-locally)
- [Known Issues and Limitations](#known-issues-and-limitations)

---

## Architecture

```
                 +------------------+
                 |  GitHub (repo)   |
                 +--------+---------+
                          |  Source (OAuth token)
                          v
+-------------------------------------------------------------+
| AWS CodePipeline  (ec2CodePipeline-<env>)                   |
|                                                             |
|   [Source] --artifact--> S3 (ec2codepipelinebucket-<env>)   |
|       |                                                     |
|       v                                                     |
|   [Deploy] --> AWS CodeDeploy (ec2CodeDeployApp-<env>)      |
+-------------------------------------------------------------+
                          |
                          |  Deployment group: tag Application=<env>
                          |  Strategy: OneAtATime + automatic rollback
                          v
+-------------------------------------------------------------+
| VPC 10.0.0.0/16                                             |
|                                                             |
|   Public subnet  --  Internet Gateway                       |
|                                                             |
|   Network Load Balancer (TCP :80)                           |
|          |                       |                          |
|          v                       v                          |
|   EC2 webapp01            EC2 webapp02 (prod only)          |
|   Docker + CodeDeploy     Docker + CodeDeploy               |
|   container :80 -> :8000  container :80 -> :8000            |
+-------------------------------------------------------------+
```

---

## Repository Structure

```
.
├── main.tf                  # Root module: instantiates the environment module (prod enabled, staging commented out)
├── provider.tf              # AWS provider and S3 remote state backend
├── variables.tf             # Root module input variables
├── variables.auto.tfvars    # Default values (region, environment)
├── output.tf                # Root module outputs
├── app.sh                   # EC2 user_data (Docker, Docker Compose and CodeDeploy agent)
├── appspec.yml              # CodeDeploy application specification
├── Dockerfile               # Application image (gunicorn + Flask)
├── docker-compose.yml       # Container orchestration on the instances
├── app/
│   ├── api.py               # Flask comments API
│   └── requirements.txt     # Python dependencies
├── scripts/                 # CodeDeploy lifecycle hooks
│   ├── beforeBuild.sh
│   ├── servicesTest.sh
│   ├── buildImage.sh
│   ├── validApp.sh
│   └── testApp.sh
├── prod/                    # Terraform module for the production environment
└── staging/                 # Terraform module for the staging environment
```

The `prod/` and `staging/` modules contain the same files. They differ only in resource names, subnet and pipeline artifact name:

| File              | Responsibility                                                       |
|-------------------|----------------------------------------------------------------------|
| `network.tf`      | VPC, public subnet, Internet Gateway, route table and security group |
| `ec2.tf`          | Amazon Linux 2 AMI lookup and application EC2 instances              |
| `nlb.tf`          | Network Load Balancer, target group, listener and attachments        |
| `iam.tf`          | Roles and policies for CodeDeploy, CodePipeline and EC2 instances    |
| `codedeploy.tf`   | CodeDeploy application and deployment group                          |
| `codepipeline.tf` | S3 artifact bucket and pipeline (GitHub Source and CodeDeploy Deploy)|
| `variables.tf`    | Module variables                                                     |
| `output.tf`       | Instance public DNS names and load balancer DNS name                 |

---

## Provisioned Resources

| Category       | Resource                                   | Details                                                                  |
|----------------|--------------------------------------------|--------------------------------------------------------------------------|
| Networking     | `aws_vpc.webapps`                          | CIDR `10.0.0.0/16`, DNS hostnames enabled                                |
|                | `aws_subnet`                               | Public subnet (`map_public_ip_on_launch = true`)                         |
|                | `aws_internet_gateway` / `aws_route_table` | `0.0.0.0/0` route to the Internet Gateway                                |
|                | `aws_security_group`                       | Port 80 open to the internet; port 22 restricted to a single `/32` IP   |
| Compute        | `aws_instance.webapps`                     | `t2.micro`, Amazon Linux 2, 2 instances in `prod` and 1 otherwise        |
| Load balancing | `aws_lb` (network)                         | TCP 80 listener forwarding to a TCP 80 target group                      |
| IAM            | `CodeDeployRole-<env>`                     | Role assumed by CodeDeploy                                               |
|                | `EC2InstanceRole-<env>` + instance profile | S3 read access (artifact download by the CodeDeploy agent)               |
|                | `ec2CodePipelineRole-<env>`                | Role assumed by CodePipeline                                             |
| CI/CD          | `aws_s3_bucket`                            | `ec2codepipelinebucket-<env>`, private, `force_destroy = true`           |
|                | `aws_codedeploy_app` / deployment group    | `CodeDeployDefault.OneAtATime`, auto rollback on `DEPLOYMENT_FAILURE`    |
|                | `aws_codepipeline`                         | `Source` (GitHub) and `Deploy` (CodeDeploy) stages                       |

The deployment group selects its target instances by the tag `Application = <environment>`. Terraform applies this tag to the instances it creates.

---

## Application

The application is a REST API for comments, written in Flask and served by gunicorn on port `8000` inside the container. Docker Compose publishes it on port `80` of the instance. Data is stored in memory only and is lost when the container restarts.

### Endpoints

| Method | Route                            | Description                                    |
|--------|----------------------------------|------------------------------------------------|
| POST   | `/api/comment/new`               | Creates a comment associated with a `content_id` |
| GET    | `/api/comment/list/<content_id>` | Lists the comments for a `content_id`          |

### Examples

Create a comment:

```bash
curl -X POST http://<host>/api/comment/new \
  -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","comment":"First comment","content_id":1}'
```

Response:

```json
{
  "status": "SUCCESS",
  "message": "comment created and associated with content_id 1"
}
```

List comments:

```bash
curl http://<host>/api/comment/list/1
```

If the `content_id` does not exist, the API returns HTTP `404`:

```json
{
  "status": "NOT-FOUND",
  "message": "content_id 1 not found"
}
```

---

## Deployment Lifecycle (CodeDeploy)

`appspec.yml` copies `app/`, `Dockerfile` and `docker-compose.yml` to `/etc/deploy/` on the instance and runs the following hooks:

| Hook               | Script                    | Purpose                                                                   |
|--------------------|---------------------------|---------------------------------------------------------------------------|
| `BeforeInstall`    | `scripts/beforeBuild.sh`  | Waits 60s and checks Docker, the CodeDeploy agent and Docker Compose      |
| `AfterInstall`     | `scripts/servicesTest.sh` | Runs the `hello-world` container to validate Docker                       |
| `ApplicationStart` | `scripts/buildImage.sh`   | Runs `docker-compose up -d` (builds the `globoapp:v1.0` image) as root    |
| `ValidateService`  | `scripts/validApp.sh`     | Sends a POST and a GET to the API on `localhost:80` (smoke test)          |

`scripts/testApp.sh` contains the same smoke test for manual use.

Instances are bootstrapped by `app.sh`, applied as `user_data`. It installs Ruby, the AWS CLI, the CodeDeploy agent, Docker, Docker Compose `1.25.5` and Git.

---

## Prerequisites

- [Terraform](https://www.terraform.io/) compatible with AWS provider `~> 2.0` (0.12/0.13 series)
- AWS credentials configured (`aws configure`, environment variables or a named profile)
- An S3 bucket for remote state, as defined in `provider.tf`
- An EC2 key pair named `MyWebServers` in the target region
- A GitHub repository containing this project (with `appspec.yml` at its root) and a personal access token (OAuth) with read access to it

---

## Configuration

### Remote Backend

Terraform state is stored in S3. Point the `backend` block in `provider.tf` to your own bucket:

```hcl
terraform {
  backend "s3" {
    bucket = "<your-state-bucket>"
    key    = "webapp.tfstate"
    region = "us-east-1"
  }
}
```

### Variables

| Variable                | Description                              | Default                   |
|-------------------------|------------------------------------------|---------------------------|
| `region`                | AWS region                               | `us-east-1` (tfvars)      |
| `environment`           | Environment name (`prod` or `staging`)   | `prod` (tfvars)           |
| `git_repository_owner`  | GitHub owner (user or organization)      | `awscode`                 |
| `git_repository_name`   | GitHub repository name                   | `paulo-ambrosio`          |
| `git_repository_branch` | Branch the pipeline pulls from           | `master`                  |
| `git_token`             | GitHub OAuth token                       | `tokenGit` (placeholder)  |

Do not store the GitHub token in versioned files. Pass it as an environment variable instead:

```bash
export TF_VAR_git_token="<your-github-token>"
```

### SSH Access

The security group allows SSH only from a single fixed IP (`/32`), set in each module's `network.tf`. Replace it with your own IP before applying.

### Selecting the Environment

`main.tf` enables only the `prod` module. To use staging:

1. Uncomment the `module "staging"` block in `main.tf` (and comment out `module "prod"` if desired).
2. In `output.tf`, change the `module.prod` references to `module.staging`.
3. Set `environment = "staging"` in `variables.auto.tfvars`.

---

## Usage

Run all commands from the repository root, because `user_data` loads `app.sh` by relative path.

```bash
# Initialize providers, modules and backend
terraform init

# Review the execution plan
terraform plan

# Provision the infrastructure
terraform apply

# Tear down all infrastructure
terraform destroy
```

The pipeline is created with `PollForSourceChanges = false`, so it does not pick up new commits on its own. Start a run from the console, or with:

```bash
aws codepipeline start-pipeline-execution --name ec2CodePipeline-prod
```

---

## Outputs

| Output       | Description                                        |
|--------------|----------------------------------------------------|
| `public_dns` | Public DNS names of the EC2 instances              |
| `alb_dns`    | DNS name of the Network Load Balancer (entry point)|

```bash
terraform output alb_dns
curl http://$(terraform output -raw alb_dns)/api/comment/list/99
```

---

## Running the Application Locally

With Docker and Docker Compose installed:

```bash
docker-compose up -d --build
curl http://localhost/api/comment/list/1
```

Or directly with Python 3:

```bash
cd app
pip install -r requirements.txt
gunicorn --bind 0.0.0.0:8000 api:app
```

---

## Known Issues and Limitations

Review the following points in the current code before using this project outside a learning context:

- **Legacy versions**: the AWS provider is pinned to `~> 2.0`. The syntax used (`acl` on `aws_s3_bucket`, `version` inside the `provider` block, `"${...}"` interpolation) dates from Terraform 0.12/0.13.
- **GitHub v1 source action**: the source stage uses the `ThirdParty/GitHub` version 1 action with an OAuth token, which AWS has deprecated. The current replacement is CodeStar Connections (`CodeStarSourceConnection`).
- **Base image**: the `Dockerfile` uses `centos:7.8.2003` with Python 2 `pip`, which cannot install the Flask and Werkzeug versions in `requirements.txt` (they require Python 3.8 or later). The `CMD` also passes an empty `--bind=`; gunicorn must listen on `0.0.0.0:8000` for the port mapping to work.
- **Production subnet**: the CIDR `10.0.1.0/20` in `prod/network.tf` is not aligned to a `/20` boundary. A valid network address would be `10.0.0.0/20` or `10.0.16.0/20`.
- **Environment coexistence**: the `CodeDeployPolicy` policy has a fixed name, and other resource names may collide if `prod` and `staging` are applied in the same account. Each module also creates its own VPC.
- **Broad IAM permissions**: the CodePipeline and instance policies use `Resource: "*"` and wildcards such as `ec2:*` and `s3:*`. Restrict them to least privilege for production use.
- **Availability**: the instances and the NLB use a single subnet, which means a single Availability Zone.
- **Persistence**: the API keeps data in memory. With multiple instances behind the NLB, each instance holds its own separate set of comments.
- **Validation scripts**: the hooks store command output in variables and do not check exit codes or HTTP responses. A failure therefore may not stop the deployment or trigger the automatic rollback.
- **CodeDeploy agent region**: `app.sh` downloads the installer from the `us-east-1` bucket. Update the URL if you deploy to another region.
