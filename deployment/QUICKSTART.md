# Quick Start Guide - Unraid Deployment

Get your Heating Design application running on Unraid in 15 minutes.

## Prerequisites Checklist

- [ ] Unraid server with Docker enabled
- [ ] SSH access to Unraid
- [ ] 10GB free disk space
- [ ] Docker installed on your development machine

## Step 1: Automated Deployment (Easiest)

```bash
# Clone the repository
git clone <repository-url>
cd Heat-loss-and-pipe-route

# Run the automated build and deploy script
./deployment/scripts/build-and-deploy.sh --unraid-ip YOUR_UNRAID_IP
```

When prompted, enter:
- Your Unraid server IP address
- SSH password (if not using keys)

The script will:
1. ✓ Build Docker images
2. ✓ Transfer to Unraid
3. ✓ Create directory structure
4. ✓ Deploy containers
5. ✓ Verify deployment

---

## Step 2: Configure Environment

SSH into your Unraid server:

```bash
ssh root@YOUR_UNRAID_IP
cd /mnt/user/appdata/heating-design
nano .env
```

**Required changes:**

```bash
# Generate with: openssl rand -hex 32
DB_PASSWORD=your_secure_password_here

# Generate with: openssl rand -hex 32
JWT_SECRET=your_jwt_secret_here

# Generate with: openssl rand -hex 24
API_KEY=your_api_key_here

# Your Unraid IP
UNRAID_IP=192.168.1.XXX
API_URL=http://192.168.1.XXX:3001
```

Save with `Ctrl+O`, `Enter`, `Ctrl+X`

---

## Step 3: Restart Services

```bash
cd /mnt/user/appdata/heating-design
docker compose down
docker compose up -d
```

---

## Step 4: Verify It's Working

**Test API:**
```bash
curl http://YOUR_UNRAID_IP:3001/health
```

Expected: `{"status":"ok"}`

**Test Web UI:**

Open in browser: `http://YOUR_UNRAID_IP:3000`

---

## Step 5: Create Admin User

Access the API container:

```bash
docker exec -it heating_design_api sh

# Inside container, create admin user:
node -e "
const crypto = require('crypto');
console.log('Admin password hash:', crypto.createHash('sha256').update('YourPassword123').digest('hex'));
"
```

Or use the API:

```bash
curl -X POST http://YOUR_UNRAID_IP:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@yourdomain.com",
    "password": "YourSecurePassword123",
    "fullName": "Administrator"
  }'
```

---

## Atlas Integration (Optional)

### Configure Atlas App

In your Atlas iOS app, set:

**API URL:** `http://YOUR_UNRAID_IP:3001`
**API Key:** (from your `.env` file)

### Test Connection

From Atlas app, make a test request:

```swift
let url = URL(string: "http://YOUR_UNRAID_IP:3001/health")!
let (data, _) = try await URLSession.shared.data(from: url)
print(String(data: data, encoding: .utf8)!)
```

---

## Troubleshooting

### Containers Not Starting

```bash
# Check logs
docker compose logs -f

# Check specific service
docker compose logs heating_api
```

### API Not Responding

```bash
# Check if container is running
docker ps | grep heating_api

# Restart API
docker compose restart heating_api

# Check API logs
docker compose logs heating_api --tail=50
```

### Database Connection Error

```bash
# Test database
docker exec heating_design_db psql -U heating_admin -d heating_design -c "SELECT 1"

# Reset database (WARNING: deletes all data)
docker compose down -v
docker compose up -d
```

### Web UI Shows 404

```bash
# Check nginx logs
docker compose logs heating_web

# Verify files exist
docker exec heating_design_web ls -la /usr/share/nginx/html/

# Rebuild and redeploy web container
docker compose up -d --force-recreate heating_web
```

---

## What's Next?

1. **Set up backups** - See [DEPLOYMENT_GUIDE.md](unraid/DEPLOYMENT_GUIDE.md#maintenance--backups)
2. **Configure HTTPS** - Set up reverse proxy with SSL
3. **Integrate with Atlas** - See [Atlas Integration Guide](atlas-integration/README.md)
4. **Customize settings** - Edit `.env` for advanced configuration

---

## Quick Reference

### Useful Commands

```bash
# View all container logs
docker compose logs -f

# Restart all services
docker compose restart

# Stop all services
docker compose down

# Start services
docker compose up -d

# Check container status
docker ps | grep heating

# Access API container shell
docker exec -it heating_design_api sh

# Access database
docker exec -it heating_design_db psql -U heating_admin -d heating_design

# Manual backup
docker exec heating_design_db pg_dump -U heating_admin heating_design > backup.sql

# Check disk usage
docker system df
```

### Access URLs

- **Web UI:** http://YOUR_UNRAID_IP:3000
- **API:** http://YOUR_UNRAID_IP:3001
- **Health Check:** http://YOUR_UNRAID_IP:3001/health
- **Database:** localhost:5433 (from containers only)

### File Locations on Unraid

- **App Data:** `/mnt/user/appdata/heating-design/`
- **Database:** `/mnt/user/appdata/heating-design/db/`
- **Uploads:** `/mnt/user/appdata/heating-design/uploads/`
- **Backups:** `/mnt/user/appdata/heating-design/backups/`
- **Logs:** `/mnt/user/appdata/heating-design/logs/`

---

## Support

For detailed documentation, see:
- [Complete Deployment Guide](unraid/DEPLOYMENT_GUIDE.md)
- [Atlas Integration](atlas-integration/README.md)
- [Docker Compose Configuration](unraid/docker-compose.yml)

**Need help?** Check the troubleshooting section or review container logs.

---

🎉 **Congratulations!** Your Heating Design application is now running on Unraid.
