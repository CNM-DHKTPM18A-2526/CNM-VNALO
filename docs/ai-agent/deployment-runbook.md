# AI Assistant Deployment Runbook

> Use this runbook after changing AI web UI/runtime, AI service prompt/parser, RAG docs, or assistant-related nginx routes.

## Pre-Deploy Checks

```bash
cd ~/CNM-VNALO
git status --short
git branch --show-current
git fetch origin
git log --oneline --decorate -5
```

Confirm the target branch before pulling. For the current PR train, web AI changes normally deploy from `nguyenvu`.

## Frontend Web Redeploy

```bash
cd ~/CNM-VNALO
git fetch origin
git checkout nguyenvu
git pull --ff-only origin nguyenvu
cd docker
docker compose build frontend-web
docker compose up -d frontend-web
docker compose ps frontend-web
docker compose logs --tail=120 frontend-web
./deploy.sh --health
```

## AI Service Redeploy

```bash
cd ~/CNM-VNALO
git fetch origin
git checkout nguyenvu
git pull --ff-only origin nguyenvu
cd docker
docker compose build ai-service
docker compose up -d ai-service
sleep 30
docker compose ps ai-service
docker compose logs --tail=200 ai-service
curl -i http://localhost:8094/api/v1/ai/actuator/health
./deploy.sh --health
```

## Public Gateway Verification

```bash
curl -i https://vnalo.fit/api/v1/ai/actuator/health
curl -i https://vnalo.fit/api/v1/ai/chat \
  -H "Authorization: Bearer $VNALO_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"hello","history":[],"analyzeIntent":true}'
```

## Common Failure Checks

```bash
# Check nginx AI routing inside the frontend container
docker exec docker-frontend-web-1 nginx -T | grep -n -A20 -B5 "location /api/v1/ai"

# Check AI service logs for provider, parser, and security errors
docker compose logs --tail=300 ai-service | grep -i -E "gemini|ollama|action|forbidden|403|error|rate|quota"

# Check public 403 vs internal success mismatch
curl -i http://localhost:8094/api/v1/ai/chat \
  -H "Authorization: Bearer $VNALO_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"hello internal","history":[],"analyzeIntent":true}'
```

## Rollback

```bash
cd ~/CNM-VNALO
git fetch origin
git checkout <known-good-tag-or-commit>
cd docker
docker compose build frontend-web ai-service
docker compose up -d frontend-web ai-service
./deploy.sh --health
```

Prefer tags for production rollback. If testing integration branches on EC2, create a tag before pulling and document the exact commit used.
