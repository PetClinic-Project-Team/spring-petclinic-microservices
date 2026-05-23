# Spring PetClinic Microservices on AWS EKS

## Project Overview

This project demonstrates the deployment of the **Spring PetClinic Microservices Application** on **Amazon Elastic Kubernetes Service (EKS)** using a cloud-native microservices architecture.

The platform was deployed using:

* Kubernetes
* Docker
* AWS EKS
* Terraform
* Amazon ECR
* AWS Load Balancer Controller
* Amazon EBS CSI Driver
* IAM & OIDC Integration
* Kubernetes Ingress & Services

The infrastructure was designed to support scalable, resilient, production-style microservices deployment with persistent storage, load balancing, and Kubernetes orchestration.

---

# My Role – Infrastructure Engineer

As the **Infrastructure Engineer**, I was responsible for designing, provisioning, configuring, securing, troubleshooting, and maintaining the AWS and Kubernetes infrastructure environment for the project.

## Responsibilities

* Provisioning AWS infrastructure using Terraform
* Creating and configuring Amazon EKS clusters
* Managing Kubernetes networking
* Installing and configuring cluster add-ons
* Managing IAM roles and RBAC access
* Configuring Kubernetes Ingress
* Installing AWS Load Balancer Controller
* Configuring persistent storage using EBS CSI Driver
* Managing namespaces and Kubernetes secrets
* Supporting application deployment teams
* Troubleshooting infrastructure and cluster issues
* Scaling and recovering worker nodes
* Cost optimisation and infrastructure maintenance

---

# Project Architecture

## High-Level Architecture

```text
Users
   ↓
AWS Application Load Balancer (ALB)
   ↓
Kubernetes Ingress
   ↓
API Gateway
   ↓
Microservices
 ├── Config Server
 ├── Discovery Server
 ├── Customers Service
 ├── Vets Service
 ├── Visits Service
 └── GenAI Service
        ↓
MySQL Databases
        ↓
Amazon EBS Persistent Volumes
```

---

# AWS Services Used

| AWS Service      | Purpose                                |
| ---------------- | -------------------------------------- |
| Amazon EKS       | Kubernetes orchestration               |
| Amazon EC2       | Worker nodes                           |
| Amazon ECR       | Container registry                     |
| Amazon VPC       | Networking                             |
| Internet Gateway | Public internet access                 |
| NAT Gateway      | Internet access for private nodes      |
| Route Tables     | Traffic routing                        |
| IAM              | Access management                      |
| OIDC Provider    | IAM Roles for Service Accounts         |
| AWS ALB          | Kubernetes ingress traffic             |
| Amazon EBS       | Persistent storage                     |
| CloudFormation   | IAM service account stack provisioning |

---

# Infrastructure Provisioning with Terraform

Terraform was used as the Infrastructure as Code (IaC) tool for provisioning cloud resources.

## Terraform Commands Used

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

---

# AWS Infrastructure Provisioned

## Networking Resources

* VPC
* Public Subnets
* Private Subnets
* Internet Gateway
* NAT Gateway
* Route Tables
* Route Table Associations
* Security Groups

## Kubernetes Infrastructure

* Amazon EKS Cluster
* Managed Node Group
* IAM Roles
* Worker Nodes

---

# EKS Cluster Configuration

## Cluster Information

| Component          | Value             |
| ------------------ | ----------------- |
| Cluster Name       | petclinic-cluster |
| Region             | us-east-1         |
| Kubernetes Version | v1.31             |
| Node Type          | t3.medium         |
| Node Group         | petclinic-workers |

---

# Connecting to the EKS Cluster

## Update kubeconfig

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name petclinic-cluster
```

## Verify Cluster Access

```bash
kubectl get nodes
```

Expected Result:

```bash
STATUS = Ready
```

---

# Kubernetes Namespace Management

Created a dedicated namespace for the application.

## Create Namespace

```bash
kubectl create namespace spring-petclinic
```

## Verify Namespace

```bash
kubectl get ns
```

---

# Kubernetes Secrets Management

Configured Kubernetes secrets for MySQL credentials.

## Create MySQL Secret

```bash
kubectl create secret generic mysql-secret \
  --from-literal=username=petclinic \
  --from-literal=password=petclinic123 \
  --from-literal=database=petclinic \
  -n spring-petclinic
```

## Verify Secret

```bash
kubectl get secret -n spring-petclinic
```

---

# MySQL Deployment

Deployed MySQL databases for the microservices.

## Databases Deployed

* customers-db-mysql
* vets-db-mysql
* visits-db-mysql

## Apply MySQL Manifests

```bash
kubectl apply -f k8s/mysql/
```

## Verification

```bash
kubectl get pods -n spring-petclinic
kubectl get svc -n spring-petclinic
```

---

# Application Microservices

The project included the deployment of:

* Config Server
* Discovery Server
* API Gateway
* Customers Service
* Vets Service
* Visits Service
* GenAI Service

---

# Config Server Validation

Verified Spring Cloud Config Server functionality.

## Validation Commands

```bash
curl http://localhost:8888/vets-service/default
curl http://localhost:8888/visits-service/default
curl http://localhost:8888/api-gateway/default
```

Purpose:

* Validate configuration loading
* Confirm service configuration availability
* Ensure microservices connectivity

---

# Ingress Configuration

Configured Kubernetes Ingress using AWS Application Load Balancer.

## Deploy Ingress

```bash
kubectl apply -f k8s/ingress/
```

## Verify Ingress

```bash
kubectl get ingress -n spring-petclinic
kubectl describe ingress petclinic-ingress -n spring-petclinic
```

## ALB Annotations Used

```yaml
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
kubernetes.io/ingress.class: alb
```

---

# AWS Load Balancer Controller Installation

Installed AWS Load Balancer Controller to support ALB Ingress.

---

## Step 1 – Add Helm Repository

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

---

## Step 2 – Associate IAM OIDC Provider

```bash
eksctl utils associate-iam-oidc-provider \
  --region us-east-1 \
  --cluster petclinic-cluster \
  --approve
```

---

## Step 3 – Download IAM Policy

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
```

---

## Step 4 – Create IAM Policy

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

Encountered:

```text
EntityAlreadyExists
```

Meaning:

* Policy already existed
* Safe to continue

---

## Step 5 – Create IAM Service Account

```bash
eksctl create iamserviceaccount \
  --cluster=petclinic-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region us-east-1
```

---

## Step 6 – Install Controller Using Helm

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=petclinic-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=<VPC-ID>
```

---

# Major OIDC Trust Policy Issue

## Problem

AWS Load Balancer Controller failed with:

```text
AccessDenied
```

## Root Cause

Incorrect OIDC provider ID in IAM trust relationship.

## Resolution

* Updated IAM trust policy
* Corrected OIDC provider reference
* Restarted AWS Load Balancer Controller

## Result

```bash
aws-load-balancer-controller = Running
```

---

# EBS CSI Driver Installation

Installed EBS CSI Driver to support persistent storage for databases.

---

## Create IAM Service Account

```bash
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster petclinic-cluster \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --region us-east-1
```

---

## Install Addon

```bash
aws eks create-addon \
  --cluster-name petclinic-cluster \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1
```

---

# EBS CSI Driver CrashLoopBackOff Issue

## Problem

```text
CrashLoopBackOff
```

## Cause

Incorrect IAM role permissions.

## Resolution

* Attached correct IAM policies
* Reconfigured service account
* Restarted EBS CSI Driver

## Verification

```bash
kubectl get pods -n kube-system
```

Expected:

```bash
ebs-csi-controller = Running
```

---

# Persistent Volume Verification

```bash
kubectl get pvc -n spring-petclinic
```

Expected:

```text
STATUS = Bound
```

Meaning:

* Amazon EBS volumes provisioned successfully
* Databases configured with persistent storage

---

# IAM Roles and Access Management

Created IAM roles for secure team collaboration and Kubernetes access.

## Roles Created

| Role                                | Purpose                    |
| ----------------------------------- | -------------------------- |
| EKS-Developer-Role                  | Developer cluster access   |
| EKS-Database-Role                   | Database management        |
| AmazonEKSLoadBalancerControllerRole | ALB Controller permissions |
| AmazonEKS_EBS_CSI_DriverRole        | EBS CSI permissions        |

---

# Team Access Configuration

Configured:

* IAM Users
* IAM Roles
* AssumeRole policies
* EKS Access Entries
* Kubernetes access permissions

Used commands such as:

```bash
aws eks create-access-entry
```

and

```bash
eksctl create iamidentitymapping
```

---

# Node Scaling and Recovery

## Problem Encountered

One worker node became overloaded and unhealthy.

### Symptoms

* Pods stuck in Pending state
* High CPU usage
* Scheduling failures
* Services unavailable

---

# Scaling Solution

## Scale Node Group

```bash
aws eks update-nodegroup-config \
  --cluster-name petclinic-cluster \
  --nodegroup-name petclinic-workers \
  --scaling-config minSize=2,maxSize=3,desiredSize=2 \
  --region us-east-1
```

---

# Worker Node Recovery

## Drained Broken Node

```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

## Deleted Node

```bash
kubectl delete node <node-name>
```

## Auto Scaling Recovery

AWS Auto Scaling automatically provisioned replacement worker nodes.

---

# NAT Gateway Cost Optimisation

To reduce AWS costs:

* NAT Gateway was temporarily removed
* Worker nodes lost outbound internet access
* Cluster networking issues occurred

## Issues Encountered

* Image pull failures
* Kubernetes API timeout
* DNS resolution problems

## Resolution

Terraform recreated the NAT Gateway:

```text
Plan: 1 to add, 2 to change, 0 to destroy
```

---

# Security Group Configuration

Security groups were configured to support:

* Kubernetes API communication
* Worker node communication
* ALB traffic
* Database traffic
* Outbound internet access

## Production-Style Security Group Design

Designed additional security groups for:

* Application Load Balancer
* Worker Nodes
* MySQL Database

Following security best practices:

* Principle of least privilege
* Restricted database access
* Controlled ingress and egress
* Internal cluster communication isolation

---

# Amazon ECR Configuration

Created ECR repositories for application container images.

## Example

```bash
aws ecr create-repository \
  --repository-name petclinic/spring-petclinic-genai-service \
  --region us-east-1
```

---

# Major Troubleshooting Scenarios

| Issue                    | Cause                    | Resolution                   |
| ------------------------ | ------------------------ | ---------------------------- |
| No worker nodes          | Node group scaled to 0   | Increased desired capacity   |
| API timeout              | NAT Gateway deleted      | Recreated NAT Gateway        |
| Ingress no address       | ALB Controller failure   | Fixed OIDC trust             |
| EBS CSI CrashLoopBackOff | IAM permission issue     | Attached correct IAM role    |
| Pods Pending             | Node resource exhaustion | Added worker node            |
| ALB AccessDenied         | Incorrect OIDC ID        | Corrected IAM trust policy   |
| Service unavailable      | Missing endpoints        | Verified selectors/endpoints |
| Token expiration         | Expired AWS credentials  | Regenerated access keys      |
| DescribeCluster denied   | Missing IAM permission   | Attached EKS access policy   |

---

# Verification Commands

## Cluster Health

```bash
kubectl get nodes
kubectl get pods -A
```

---

## Services

```bash
kubectl get svc -n spring-petclinic
```

---

## Deployments

```bash
kubectl get deploy -n spring-petclinic
```

---

## Ingress

```bash
kubectl get ingress -n spring-petclinic
kubectl describe ingress petclinic-ingress -n spring-petclinic
```

---

## Persistent Volumes

```bash
kubectl get pvc -n spring-petclinic
```

---

# Skills Demonstrated

## AWS & Cloud Engineering

* Amazon EKS
* IAM
* VPC Networking
* Security Groups
* NAT Gateway
* Auto Scaling

## Kubernetes & DevOps

* Kubernetes Administration
* Ingress Management
* Persistent Storage
* Secrets Management
* Cluster Troubleshooting
* Node Recovery

## Infrastructure as Code

* Terraform
* Infrastructure Automation
* State Management

## Collaboration

* Team infrastructure support
* IAM access management
* Multi-team environment coordination

---

# Lessons Learned

This project provided hands-on experience in:

* AWS EKS administration
* Kubernetes operations
* IAM & OIDC integration
* Persistent storage management
* Cluster troubleshooting
* Load balancing and ingress
* Infrastructure reliability
* Kubernetes networking
* Cloud-native architecture
* Team collaboration in DevOps environments

---

# Future Improvements

Potential future enhancements include:

* Cluster Autoscaler
* Horizontal Pod Autoscaler (HPA)
* Prometheus & Grafana monitoring
* Centralised logging
* TLS/HTTPS configuration
* Route53 custom domain
* Full CI/CD automation
* GitOps deployment workflows

---

# Project Outcome

Successfully deployed and managed a production-style Kubernetes environment on AWS EKS featuring:

* Multi-node Kubernetes cluster
* Persistent EBS-backed databases
* Functional ALB ingress
* Running microservices architecture
* Secure IAM integration
* Dynamic scaling and recovery
* Infrastructure troubleshooting and optimisation

---

# Author

## Chioma Nwosu

Infrastructure Engineer – Spring PetClinic Microservices Project

### Technologies

AWS | Kubernetes | Docker | Terraform | EKS | DevOps | Cloud Infrastructure

