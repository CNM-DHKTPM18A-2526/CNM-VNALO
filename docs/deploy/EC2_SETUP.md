# =============================================================================
# VNALO — EC2 Production Setup Guide (Option 3: t3.xlarge + EFS/S3)
# =============================================================================
#
# This guide covers deploying VNALO on a single t3.xlarge EC2 instance with:
#   - EFS (Elastic File System) for persistent Docker volumes
#   - S3 for media file storage
#   - Docker Compose for orchestration
#
# Estimated cost: ~$100-130/month (t3.xlarge + EFS + S3)
#
# =============================================================================

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Step 1: Create EFS File System](#2-step-1-create-efs-file-system)
3. [Step 2: Create S3 Bucket](#3-step-2-create-s3-bucket)
4. [Step 3: Launch EC2 Instance](#4-step-3-launch-ec2-instance)
5. [Step 4: Mount EFS on EC2](#5-step-4-mount-efs-on-ec2)
6. [Step 5: Install Docker & Docker Compose](#6-step-5-install-docker--docker-compose)
7. [Step 6: Configure Environment Variables](#7-step-6-configure-environment-variables)
8. [Step 7: Deploy with Docker Compose](#8-step-7-deploy-with-docker-compose)
9. [Step 8: SSL/HTTPS Setup](#9-step-8-sslhttps-setup)
10. [Resource Planning & Monitoring](#10-resource-planning--monitoring)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

- AWS Account with appropriate IAM permissions
- Domain name (e.g., `vnalo.fit`) configured in Route 53 (optional but recommended)
- AWS CLI configured locally: `aws configure`
- SSH key pair for EC2 access

---

## 2. Step 1: Create EFS File System

EFS provides persistent, scalable storage for Docker volumes that survives instance restarts.

### 2.1 Create EFS via AWS Console

1. Go to **AWS Console → EFS → Create file system**
2. Configure:
   - **Name**: `vnalo-efs`
   - **VPC**: Select your VPC
   - **Availability Zones**: Leave at default (Regional)
   - **Throughput mode**: `Bursting` (default, sufficient for this workload)
   - **Storage class**: `EFS Standard` (or `EFS One Zone` for lower cost)
   - **Encryption**: Enable at rest
3. Click **Create**

### 2.2 Create Security Group for EFS

1. **AWS Console → EC2 → Security Groups → Create security group**
2. Name: `vnalo-efs-sg`
3. VPC: Select your VPC
4. Inbound rules:
   ```
   Type: NFS (2049)  |  Source: <your EC2 security group>
   ```
5. Click **Create**

### 2.3 Mount EFS on EC2 (Manual)

After EC2 is running, mount EFS:

```bash
# Install NFS client
sudo yum install -y amazon-efs-utils

# Create mount point
sudo mkdir -p /mnt/efs

# Mount EFS (replace fs-xxxxxxx with your EFS filesystem ID)
sudo mount -t efs -o tls fs-xxxxxxx:/ /mnt/efs

# Add to /etc/fstab for auto-mount on reboot
echo "fs-xxxxxxx:/ /mnt/efs efs defaults,_netdev,tls 0 0" | sudo tee -a /etc/fstab

# Verify mount
df -h | grep efs
```

---

## 3. Step 2: Create S3 Bucket

S3 stores media files (images, videos, audio) uploaded by users.

### 3.1 Create S3 Bucket

```bash
aws s3 mb s3://vnalo-media --region ap-southeast-1
```

### 3.2 Configure S3 Bucket Policy

Allow media-service to read/write:

```bash
# Create bucket policy (replace ACCOUNT_ID with your AWS account)
aws s3api put-bucket-policy \
  --bucket vnalo-media \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowMediaServiceAccess",
        "Effect": "Allow",
        "Principal": { "AWS": "arn:aws:iam::ACCOUNT_ID:root" },
        "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        "Resource": "arn:aws:s3:::vnalo-media/*"
      }
    ]
  }'
```

### 3.3 Enable CORS on S3 (if serving directly)

```bash
aws s3api put-bucket-cors --bucket vnalo-media --cors-configuration '{
  "CORSRules": [{
    "AllowedOrigins": ["https://vnalo.fit"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedHeaders": ["*"],
    "MaxAgeSeconds": 3600
  }]
}'
```

### 3.4 Enable Public Access for Media

For serving media publicly, enable block public access exceptions:

```
AWS Console → S3 → vnalo-media → Permissions
→ Block public access → Edit → Uncheck "Block all public access"
→ Save changes
```

Then make bucket public:

```bash
aws s3api put-bucket-policy --bucket vnalo-media --policy '{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicReadGetObject",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::vnalo-media/*"
  }]
}'
```

---

## 4. Step 3: Launch EC2 Instance

### 4.1 Instance Specifications

| Parameter | Value |
|-----------|-------|
| **Instance Type** | `t3.xlarge` |
| **vCPU** | 4 |
| **RAM** | 16 GB |
| **Storage** | 50 GB (gp3) for OS |
| **Region** | ap-southeast-1 (Singapore) |
| **OS** | Amazon Linux 2023 (AL2023) |

### 4.2 Create Security Group

**AWS Console → EC2 → Security Groups → Create security group**

| Name | `vnalo-ec2-sg` |
|------|-----------------|

**Inbound Rules:**

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| SSH | 22 | Your IP | SSH access |
| HTTP | 80 | 0.0.0.0/0 | HTTP (redirect to HTTPS) |
| HTTPS | 443 | 0.0.0.0/0 | HTTPS |

**Outbound Rules:** All traffic (default)

### 4.3 Launch Instance

```bash
# Using AWS CLI
aws ec2 run-instances \
  --image-id ami-0a8d6fb5f31c74a4d \
  --count 1 \
  --instance-type t3.xlarge \
  --key-name YOUR_KEY_PAIR_NAME \
  --security-group-ids sg-xxxxxxx \
  --subnet-id subnet-xxxxxxx \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=vnalo-prod}]'
```

Or launch via **AWS Console → EC2 → Instances → Launch an instance**.

### 4.4 Associate Elastic IP (Recommended)

Elastic IP prevents IP changes on instance restart:

```bash
aws ec2 allocate-address
aws ec2 associate-address --instance-id i-xxxxxxx --allocation-id eipalloc-xxxxxxx
```

---

## 5. Step 4: Mount EFS on EC2

SSH into your EC2 instance, then:

```bash
# Install EFS utilities
sudo dnf install -y amazon-efs-utils

# Create mount directory
sudo mkdir -p /mnt/efs/vnalo

# Mount EFS (using EFS mount helper with TLS)
sudo mount -t efs -o tls fs-xxxxxxx:/ /mnt/efs/vnalo

# Verify
df -h /mnt/efs/vnalo

# Add to /etc/fstab for auto-mount
echo "fs-xxxxxxx:/ /mnt/efs/vnalo efs defaults,_netdev,tls 0 0" | sudo tee -a /etc/fstab
```

---

## 6. Step 5: Install Docker & Docker Compose

SSH into EC2 and run:

```bash
# Update packages
sudo dnf update -y

# Install Docker
sudo dnf install -y docker

# Install Docker Compose v2
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group (replace 'ec2-user' with your user)
sudo usermod -aG docker ec2-user

# Verify Docker
docker --version
docker-compose --version

# Enable Docker daemon on IPv6 (optional, for nginx proxy)
sudo mkdir -p /etc/docker
echo '{"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

### 6.1 (Optional) Set Up Docker Data Root on EFS

For maximum data durability, move Docker's data root to EFS:

```bash
# Link Docker data directory to EFS
sudo mkdir -p /mnt/efs/vnalo/docker-data
sudo systemctl stop docker

# Backup existing data
sudo mv /var/lib/docker /var/lib/docker.bak

# Create symlink
sudo ln -s /mnt/efs/vnalo/docker-data /var/lib/docker

# Restore Docker
sudo systemctl start docker
```

**Warning**: This may reduce Docker performance slightly due to NFS overhead. For better performance, use local NVMe storage for Docker images and EFS only for persistent volumes.

---

## 7. Step 6: Configure Environment Variables

On the EC2 instance:

```bash
# Create project directory
sudo mkdir -p /opt/vnalo
sudo chown ec2-user:ec2-user /opt/vnalo

# Clone or copy project files
# (If using Git)
# git clone https://github.com/your-repo/vnalo.git /opt/vnalo

# Copy and configure environment
cd /opt/vnalo/docker
cp .env.example .env
nano .env  # Edit with your values
```

### Required `.env` Variables for Production

```env
# =============================================================================
# Database
# =============================================================================
DB_NAME=vnalo_core
DB_USER=postgres
DB_PASS=<strong-password-here>
DB_PORT=5432

# =============================================================================
# Redis
# =============================================================================
REDIS_PORT=6379
# REDIS_PASSWORD=<set-for-production>

# =============================================================================
# JWT (MUST be identical for all services)
# =============================================================================
JWT_SECRET=<generate-512-bit-secret-here>
JWT_ISSUER=vnalo

# =============================================================================
# Core Service
# =============================================================================
SPRING_PROFILES_ACTIVE=prod
FIREBASE_CREDENTIALS_PATH=/path/to/firebase-adminsdk.json

# =============================================================================
# OTP/SMTP
# =============================================================================
OTP_ENABLED=true
OTP_EMAIL_ENABLED=true
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
MAIL_APP_PASSWORD=<gmail-app-password>
SMTP_CONNECTION_TIMEOUT_MS=5000
SMTP_READ_TIMEOUT_MS=5000
SMTP_WRITE_TIMEOUT_MS=5000

# =============================================================================
# RabbitMQ
# =============================================================================
RABBITMQ_USER=<rabbitmq-user>
RABBITMQ_PASS=<rabbitmq-password>
RABBITMQ_PORT=5672
RABBITMQ_MGMT_PORT=15672

# =============================================================================
# AWS S3 (Media Service)
# =============================================================================
AWS_ACCESS_KEY_ID=<your-aws-access-key>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-key>
AWS_BUCKET_NAME=vnalo-media
AWS_REGION=ap-southeast-1
AWS_S3_ENDPOINT=
AWS_S3_PUBLIC_ENDPOINT=https://vnalo-media.s3.ap-southeast-1.amazonaws.com

# =============================================================================
# AI Service
# =============================================================================
GEMINI_API_KEY=<your-gemini-api-key>
GEMINI_MODEL=gemini-2.0-flash
OLLAMA_URL=http://ollama:11434
OLLAMA_MODEL=llama3.1:8b
AI_RATE_LIMIT=5
AI_RATE_LIMIT_GLOBAL=10

# =============================================================================
# AI Internal Secret
# =============================================================================
AI_INTERNAL_SECRET=<strong-internal-secret>

# =============================================================================
# Logging
# =============================================================================
LOG_LEVEL=INFO
```

---

## 8. Step 7: Deploy with Docker Compose

```bash
cd /opt/vnalo/docker

# Build and start all services
docker compose up --build -d

# Watch logs (Ctrl+C to exit)
docker compose logs -f

# Check service status
docker compose ps

# Check resource usage
docker stats --no-stream
```

### Initial Health Check

```bash
# Wait for all services to be healthy
sleep 30

# Check individual services
curl http://localhost:8081/api/v1/actuator/health
curl http://localhost:3000/api/v1/health
curl http://localhost:8083/api/v1/media/actuator/health
curl http://localhost:8094/api/v1/actuator/health
curl http://localhost:8087/api/v1/actuator/health
curl http://localhost:8085/health
```

### Stop and Restart

```bash
# Stop all services
docker compose stop

# Restart all services
docker compose restart

# Full rebuild
docker compose down && docker compose up --build -d
```

---

## 9. Step 8: SSL/HTTPS Setup

### Option A: Let's Encrypt (Recommended for Production)

```bash
# Install Certbot
sudo dnf install -y certbot python3-certbot-nginx

# Obtain SSL certificate (replace with your domain)
sudo certbot --nginx -d vnalo.fit -d www.vnalo.fit

# Auto-renewal (Certbot creates this automatically)
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer

# Test renewal
sudo certbot renew --dry-run
```

### Option B: Existing Certificate

```bash
# Copy existing certificates to the correct location
sudo mkdir -p /etc/letsencrypt/live/vnalo.fit
sudo cp fullchain.pem /etc/letsencrypt/live/vnalo.fit/fullchain.pem
sudo cp privkey.pem /etc/letsencrypt/live/vnalo.fit/privkey.pem
```

### Post-SSL: Update API URLs

After SSL is configured, update the Flutter mobile app:

```bash
# In Flutter app, update these dart defines:
--dart-define=CORE_SERVICE_URL=https://vnalo.fit/api/v1
--dart-define=MESSAGE_API_URL=https://vnalo.fit/api/v1
--dart-define=MEDIA_API_URL=https://vnalo.fit/api/v1/media
--dart-define=WS_BASE_URL=wss://vnalo.fit
```

---

## 10. Resource Planning & Monitoring

### 10.1 Expected Resource Usage (t3.xlarge, 16GB RAM)

| Service | Memory Limit | CPU Limit | Expected Usage |
|---------|--------------|------------|----------------|
| core-service | 2G | 1.5 | ~1.2-1.5G |
| ai-service | 1G | 1.0 | ~500-700M |
| media-service | 1G | 0.5 | ~400-600M |
| notification-service | 1G | 0.5 | ~300-500M |
| message-service | 512M | 0.5 | ~200-350M |
| realtime-gateway | 384M | 0.5 | ~150-250M |
| postgres | 1G | 1.0 | ~400-800M |
| redis | 384M | 0.5 | ~50-150M |
| kafka | 512M | 0.5 | ~200-400M |
| rabbitmq | 384M | 0.5 | ~150-300M |
| **Total** | **~7.2G** | **~6.5** | **~3.5-5.5G** |

**Buffer**: ~10.5GB remaining for OS, Docker overhead, and spikes.

### 10.2 Set Up CloudWatch Monitoring

```bash
# Install CloudWatch agent
sudo dnf install -y amazon-cloudwatch-agent

# Configure (create /opt/aws/amazon-cloudwatch-agent/bin/config.json)
cat > /tmp/cloudwatch-config.json << 'EOF'
{
  "agent": { "metrics_collection_interval": 60, "run_as_user": "root" },
  "metrics": {
    "namespace": "VNALO",
    "metrics_collected": {
      "cpu": { "measurement": ["cpu_usage_active"] },
      "mem": { "measurement": ["mem_used", "mem_total"] },
      "disk": { "measurement": ["disk_used", "disk_total"] }
    }
  }
}
EOF

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/tmp/cloudwatch-config.json -s
```

### 10.3 Set Up CPU/Memory Alerts

In AWS Console → CloudWatch → Alarms:

| Alarm | Condition | Action |
|-------|-----------|--------|
| High CPU | CPU > 80% for 5 min | Email notification |
| High Memory | Memory > 85% for 5 min | Email notification |
| Disk Usage | Disk > 80% | Email notification |

### 10.4 T3 Unlimited (Prevent Billing Spikes)

```bash
# Enable T3 Unlimited to prevent CPU throttling
aws ec2 modify-instance-credit-specification \
  --instance-credit-specifications "InstanceId=i-xxxxxxx,CpuCredits=unlimited"
```

---

## 11. Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs <service-name>

# Inspect container
docker inspect <container-id>

# Check resource limits
docker stats --no-stream
```

### Out of Memory (OOM)

```bash
# Find which container is OOM
dmesg | grep -i "out of memory"
docker compose ps

# Temporarily increase limits in docker-compose.yml, then:
docker compose up -d
```

### Kafka Consumer Lag

```bash
# Check Kafka consumer groups
docker compose exec kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --list

# Check lag for a specific group
docker compose exec kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --group <group-name>
```

### EFS Mount Issues

```bash
# Verify EFS is accessible
curl -s https://efs-utils.s3.amazonaws.com/eks/latest/linux/amd64/amazon-efs-utils.rpm

# Check mount status
mount | grep efs

# Remount with debug
sudo mount -t efs -o tls,debug fs-xxxxxxx:/ /mnt/efs/vnalo
```

### Database Connection Refused

```bash
# Check Postgres is running
docker compose ps postgres

# Check Postgres logs
docker compose logs postgres

# Test connection from another container
docker compose exec core-service sh -c "nc -zv postgres 5432"
```

### SSL Certificate Issues

```bash
# Check certificate expiration
sudo certbot certificates

# Force renewal
sudo certbot renew --force-renewal

# Restart nginx
docker compose restart frontend-web
```

---

## Quick Reference

```bash
# Deploy
cd /opt/vnalo/docker
docker compose up --build -d

# Logs
docker compose logs -f --tail=100

# Restart all
docker compose restart

# Update & redeploy
git pull && docker compose up --build -d

# Stop
docker compose down

# Resource usage
docker stats --no-stream

# SSH tunnel for debugging
ssh -L 5432:localhost:5432 -L 6379:localhost:6379 ec2-user@<elastic-ip>
```

---

## Next Steps (Future Scaling)

| Milestone | Action |
|-----------|--------|
| **User growth (>500 DAU)** | Enable Ollama for local AI inference |
| **High traffic** | Add Redis Cluster, read replicas for PostgreSQL |
| **Media heavy** | Move to CloudFront CDN for media delivery |
| **AI model training** | Add GPU instance (g4dn) for face recognition |
| **High availability** | Split to multi-instance (Option 4) |
