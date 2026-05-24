# VNALO — Deployment Guide

## Quick Deploy (Sau khi da pull code ve EC2)

```bash
cd /home/ec2-user/CNM-VNALO/docker

# Deploy all services
./deploy.sh

# Check status
./deploy.sh --status

# Tail logs
./deploy.sh --logs
```

## Deploy mot service cu the

```bash
# Chi build va deploy 1 service
./deploy.sh core-service    # hoac ai-service, message-service, media-service, ...
```

## Troubleshooting

```bash
# Xem logs cu the
docker compose logs -f core-service
docker compose logs -f ai-service

# Restart 1 service
docker compose restart ai-service

# Check resource usage
docker stats --no-stream

# Full rebuild
docker compose down && ./deploy.sh
```

## Docker Image Cache

Neu muon tang toc do build, dam bao Docker daemon co image cache:

```bash
# Build khong cache (chi khi thay doi Docker file)
docker compose build --no-cache core-service

# Pull latest base images truoc khi build
docker compose build --pull
```

## Rollback

```bash
# Rollback 1 service
./rollback.sh core-service

# Clean up old images
./rollback.sh --prune
```
