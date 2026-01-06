# Heating Design Application - Unraid Deployment Guide

Complete guide for deploying the Heating Design application on Unraid NAS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Setup](#pre-deployment-setup)
3. [Building Docker Images](#building-docker-images)
4. [Deploying to Unraid](#deploying-to-unraid)
5. [Post-Deployment Configuration](#post-deployment-configuration)
6. [Atlas Integration](#atlas-integration)
7. [Maintenance & Backups](#maintenance--backups)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required
- Unraid server with Docker support enabled
- At least 2GB free RAM
- 10GB free disk space on Unraid array
- SSH access to your Unraid server
- Basic familiarity with Docker and command line

### Recommended
- Static IP for your Unraid server
- Reverse proxy (Nginx Proxy Manager or Traefik) for HTTPS
- User Scripts plugin for automated backups
- Community Applications plugin for easier management

---

## Pre-Deployment Setup

### 1. Enable Docker on Unraid

1. Navigate to **Settings** → **Docker**
2. Enable Docker: **Yes**
3. Set Docker storage location (default is usually fine)
4. Apply changes

### 2. Create Application Directories

SSH into your Unraid server and create the directory structure:

```bash
# Create base directory
mkdir -p /mnt/user/appdata/heating-design

# Create subdirectories for persistent data
mkdir -p /mnt/user/appdata/heating-design/{db,uploads,exports,temp,logs,redis,backups}

# Set permissions
chmod -R 755 /mnt/user/appdata/heating-design
```

### 3. Install Required Plugins (Optional but Recommended)

From Unraid **Plugins** tab:
- **Community Applications** - Easier app installation
- **User Scripts** - For automated backup scripts
- **Compose Manager** - For managing docker-compose files
- **Unraid API** - For integration with external systems

---

## Building Docker Images

You have three options for building images:

### Option A: Build on Development Machine (Recommended)

```bash
# On your development machine

# 1. Clone the repository
git clone <repository-url>
cd Heat-loss-and-pipe-route

# 2. Build API image
docker build -f deployment/docker/api/Dockerfile -t heating-design-api:latest .

# 3. Build Web UI image
docker build -f deployment/docker/web/Dockerfile \
  --build-arg VITE_API_URL=http://YOUR_UNRAID_IP:3001 \
  -t heating-design-web:latest .

# 4. Save images as tar files
docker save heating-design-api:latest | gzip > heating-design-api.tar.gz
docker save heating-design-web:latest | gzip > heating-design-web.tar.gz

# 5. Transfer to Unraid
scp heating-design-api.tar.gz root@YOUR_UNRAID_IP:/mnt/user/appdata/heating-design/
scp heating-design-web.tar.gz root@YOUR_UNRAID_IP:/mnt/user/appdata/heating-design/

# 6. On Unraid, load the images
ssh root@YOUR_UNRAID_IP
docker load < /mnt/user/appdata/heating-design/heating-design-api.tar.gz
docker load < /mnt/user/appdata/heating-design/heating-design-web.tar.gz
```

### Option B: Build Directly on Unraid

```bash
# SSH into Unraid
ssh root@YOUR_UNRAID_IP

# Clone repository
cd /tmp
git clone <repository-url>
cd Heat-loss-and-pipe-route

# Build images
docker build -f deployment/docker/api/Dockerfile -t heating-design-api:latest .
docker build -f deployment/docker/web/Dockerfile -t heating-design-web:latest .
```

### Option C: Use Docker Registry

If you have a private registry:

```bash
# On development machine
docker tag heating-design-api:latest your-registry.local/heating-design-api:latest
docker tag heating-design-web:latest your-registry.local/heating-design-web:latest
docker push your-registry.local/heating-design-api:latest
docker push your-registry.local/heating-design-web:latest

# On Unraid
docker pull your-registry.local/heating-design-api:latest
docker pull your-registry.local/heating-design-web:latest
```

---

## Deploying to Unraid

### 1. Copy Deployment Files

```bash
# On your development machine
scp -r deployment/unraid/* root@YOUR_UNRAID_IP:/mnt/user/appdata/heating-design/
```

### 2. Configure Environment Variables

SSH into Unraid and edit the environment file:

```bash
ssh root@YOUR_UNRAID_IP
cd /mnt/user/appdata/heating-design
cp .env.example .env
nano .env
```

**Required configuration:**

```bash
# Update these values!
DB_PASSWORD=your_secure_database_password_here
JWT_SECRET=your_jwt_secret_at_least_32_characters
API_KEY=your_api_key_for_atlas_integration
UNRAID_IP=192.168.1.XXX  # Your Unraid server IP
API_URL=http://192.168.1.XXX:3001
```

**Generate secure secrets:**

```bash
# Generate database password
openssl rand -base64 32

# Generate JWT secret
openssl rand -hex 32

# Generate API key
openssl rand -hex 24
```

### 3. Deploy with Docker Compose

```bash
# Navigate to deployment directory
cd /mnt/user/appdata/heating-design

# Start the stack
docker compose up -d

# Watch logs to ensure successful startup
docker compose logs -f
```

Expected output:
```
heating_design_db     | PostgreSQL init process complete; ready for start up
heating_design_api    | Server started on port 3001
heating_design_web    | /docker-entrypoint.sh: Configuration complete
```

### 4. Verify Deployment

```bash
# Check container status
docker ps | grep heating

# Check API health
curl http://localhost:3001/health

# Check Web UI
curl http://localhost:3000
```

---

## Post-Deployment Configuration

### 1. Create Admin User

```bash
# Access the API container
docker exec -it heating_design_api sh

# Run user creation script (you'll need to create this)
node scripts/create-admin.js
```

Or use the API directly:

```bash
curl -X POST http://YOUR_UNRAID_IP:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "your_secure_password",
    "fullName": "Administrator"
  }'
```

### 2. Configure Reverse Proxy (Optional)

If using **Nginx Proxy Manager**:

1. Add new Proxy Host
2. Domain: `heating.yourdomain.com`
3. Forward to: `YOUR_UNRAID_IP:3000`
4. Enable SSL with Let's Encrypt

If using **Traefik** (already configured in docker-compose.yml):

1. Ensure Traefik labels are uncommented
2. Add DNS entries for `heating.local` and `heating-api.local`
3. Configure SSL certificates

### 3. Test All Endpoints

```bash
# Health check
curl http://YOUR_UNRAID_IP:3001/health

# Login test
curl -X POST http://YOUR_UNRAID_IP:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "your_password"}'

# Access web UI
open http://YOUR_UNRAID_IP:3000
```

---

## Atlas Integration

### Setting Up Atlas to Call Heating Design API

#### 1. Configure API Key

In your `.env` file, ensure these are set:

```bash
API_KEY=your_generated_api_key_here
ATLAS_INTEGRATION=true
ATLAS_CALLBACK_URL=atlas://callback/heating-design
```

Restart the API container:

```bash
docker compose restart heating_api
```

#### 2. Atlas App Configuration

In your Atlas iOS app, add the API endpoint:

```typescript
// Atlas configuration
const HEATING_API = {
  baseUrl: 'http://YOUR_UNRAID_IP:3001',
  apiKey: 'your_generated_api_key_here',
  timeout: 30000
};

// Example: Create project from Atlas survey data
async function sendToHeatingDesign(surveyData) {
  const response = await fetch(`${HEATING_API.baseUrl}/api/atlas/import`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': HEATING_API.apiKey
    },
    body: JSON.stringify({
      surveyId: surveyData.id,
      rooms: surveyData.rooms,
      buildingData: surveyData.building,
      floorPlan: surveyData.floorPlanUrl
    })
  });

  const result = await response.json();
  return result.projectId;
}

// Example: Get calculation results
async function getHeatingResults(projectId) {
  const response = await fetch(
    `${HEATING_API.baseUrl}/api/projects/${projectId}/results`,
    {
      headers: {
        'X-API-Key': HEATING_API.apiKey
      }
    }
  );

  return await response.json();
}
```

#### 3. Network Configuration

Ensure your iPad running Atlas can reach your Unraid server:

**Same Network:**
- Use local IP: `http://192.168.1.XXX:3001`
- No additional configuration needed

**Different Networks:**
- Set up VPN (WireGuard recommended)
- Or expose via reverse proxy with authentication
- Configure firewall rules as needed

---

## Maintenance & Backups

### Automated Database Backups

The docker-compose includes a backup service that runs daily at midnight.

**Manual backup:**

```bash
# Create manual backup
docker exec heating_design_db pg_dump -U heating_admin heating_design | gzip > backup_$(date +%Y%m%d).sql.gz

# Copy to safe location
cp backup_*.sql.gz /mnt/user/backups/heating-design/
```

**Restore from backup:**

```bash
# Stop the API
docker compose stop heating_api

# Restore database
gunzip < backup_20240115.sql.gz | docker exec -i heating_design_db psql -U heating_admin -d heating_design

# Restart services
docker compose start heating_api
```

### Update Strategy

```bash
# 1. Pull latest code
cd /tmp
git clone <repository-url>
cd Heat-loss-and-pipe-route

# 2. Build new images
docker build -f deployment/docker/api/Dockerfile -t heating-design-api:latest .
docker build -f deployment/docker/web/Dockerfile -t heating-design-web:latest .

# 3. Backup current database
docker exec heating_design_db pg_dump -U heating_admin heating_design > /mnt/user/appdata/heating-design/backups/pre-update-backup.sql

# 4. Stop containers
cd /mnt/user/appdata/heating-design
docker compose down

# 5. Start with new images
docker compose up -d

# 6. Check logs
docker compose logs -f
```

### Monitoring

**View logs:**

```bash
# All containers
docker compose logs -f

# Specific service
docker compose logs -f heating_api

# Last 100 lines
docker compose logs --tail=100 heating_api
```

**Resource usage:**

```bash
# Container stats
docker stats --no-stream

# Disk usage
docker system df
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs heating_api

# Check configuration
docker compose config

# Verify environment file
cat .env | grep -v "^#" | grep -v "^$"
```

### Database Connection Issues

```bash
# Test database connection
docker exec heating_design_db psql -U heating_admin -d heating_design -c "SELECT 1"

# Check database logs
docker compose logs heating_db

# Verify password matches .env
docker compose exec heating_api env | grep DB_PASSWORD
```

### API Not Responding

```bash
# Check if API is running
docker ps | grep heating_api

# Check API logs
docker compose logs heating_api --tail=50

# Test direct connection
docker exec -it heating_design_api wget -O- http://localhost:3001/health

# Check network
docker network inspect heating_design_network
```

### Web UI Not Loading

```bash
# Check nginx logs
docker compose logs heating_web

# Verify nginx configuration
docker exec heating_design_web nginx -t

# Check if files exist
docker exec heating_design_web ls -la /usr/share/nginx/html/
```

### File Upload Issues

```bash
# Check upload directory permissions
docker exec heating_design_api ls -la /app/uploads

# Check disk space
df -h /mnt/user/appdata/heating-design/

# Verify volume mounts
docker compose config | grep volumes -A 5
```

### Atlas Connection Issues

```bash
# Test API from iPad network
# On iPad/Atlas device, use browser or curl:
curl http://YOUR_UNRAID_IP:3001/health

# Check firewall on Unraid
iptables -L | grep 3001

# Verify API key
curl -H "X-API-Key: your_api_key" http://YOUR_UNRAID_IP:3001/api/atlas/status
```

---

## Performance Optimization

### For Better Performance on Unraid:

**1. Use Cache Drive**

Move appdata to cache for better I/O:

```bash
mv /mnt/user/appdata/heating-design /mnt/cache/appdata/
ln -s /mnt/cache/appdata/heating-design /mnt/user/appdata/heating-design
```

**2. Adjust Docker Settings**

In `.env`:

```bash
# Increase worker processes for API
API_WORKERS=4

# Adjust database connections
DB_MAX_CONNECTIONS=50
```

**3. Enable Redis Caching**

Uncomment the Redis service in docker-compose.yml and restart.

---

## Security Best Practices

1. **Change default passwords** - Use strong, unique passwords
2. **Use HTTPS** - Set up reverse proxy with SSL
3. **Regular backups** - Automated daily backups
4. **Update regularly** - Keep Docker images updated
5. **Monitor logs** - Regular log review for suspicious activity
6. **API key rotation** - Rotate API keys periodically
7. **Network isolation** - Consider VLAN for IoT devices accessing the API

---

## Support & Resources

- **GitHub Repository**: [Link to repo]
- **Documentation**: [Link to docs]
- **Unraid Forums**: https://forums.unraid.net/
- **Docker Documentation**: https://docs.docker.com/

---

## Quick Command Reference

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart a specific service
docker compose restart heating_api

# View logs
docker compose logs -f

# Access container shell
docker exec -it heating_design_api sh

# Database backup
docker exec heating_design_db pg_dump -U heating_admin heating_design > backup.sql

# Update images
docker compose pull
docker compose up -d

# Clean up unused images
docker image prune -a
```

---

**Deployment Complete! 🎉**

Your Heating Design application should now be running on Unraid:
- Web UI: http://YOUR_UNRAID_IP:3000
- API: http://YOUR_UNRAID_IP:3001
- Database: localhost:5433 (accessible only from containers)
