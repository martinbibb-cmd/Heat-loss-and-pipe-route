# Deployment Documentation

Complete deployment infrastructure for the Heating Design application.

## Overview

This directory contains everything needed to deploy the Heating Design application on Unraid NAS:

```
deployment/
├── README.md                       # This file
├── QUICKSTART.md                   # 15-minute deployment guide
│
├── unraid/                         # Unraid-specific deployment
│   ├── docker-compose.yml          # Docker Compose configuration
│   ├── .env.example                # Environment variables template
│   ├── DEPLOYMENT_GUIDE.md         # Comprehensive deployment guide
│   └── init-scripts/               # Database initialization
│       ├── 01-init-database.sql
│       └── 02-create-tables.sql
│
├── docker/                         # Docker images
│   ├── api/
│   │   └── Dockerfile              # API container (Node.js)
│   └── web/
│       ├── Dockerfile              # Web UI container (React/Nginx)
│       └── nginx.conf              # Nginx configuration
│
├── atlas-integration/              # Atlas app integration
│   └── README.md                   # Integration guide & code examples
│
└── scripts/                        # Automation scripts
    └── build-and-deploy.sh         # Automated build & deployment
```

## Quick Links

### For First-Time Setup
👉 **[QUICKSTART.md](QUICKSTART.md)** - Get running in 15 minutes

### For Detailed Configuration
👉 **[Unraid Deployment Guide](unraid/DEPLOYMENT_GUIDE.md)** - Complete setup instructions

### For Atlas Integration
👉 **[Atlas Integration Guide](atlas-integration/README.md)** - iOS app integration

## Deployment Options

### Option 1: Automated Deployment (Recommended)

Use the provided script for one-command deployment:

```bash
./deployment/scripts/build-and-deploy.sh --unraid-ip 192.168.1.100
```

### Option 2: Manual Deployment

Follow the step-by-step guide:

1. Build Docker images
2. Transfer to Unraid
3. Configure environment
4. Deploy with Docker Compose

See [QUICKSTART.md](QUICKSTART.md) for details.

### Option 3: Docker Registry

For advanced setups with multiple servers:

1. Build and push to private registry
2. Pull from registry on Unraid
3. Deploy with Docker Compose

See [Deployment Guide](unraid/DEPLOYMENT_GUIDE.md#option-c-use-docker-registry)

## Architecture

### Container Stack

```
┌─────────────────────────────────────────┐
│         Unraid NAS Server               │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  PostgreSQL Container            │  │
│  │  - Port: 5433                    │  │
│  │  - Volume: /appdata/.../db       │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  API Container (Node.js)         │  │
│  │  - Port: 3001                    │  │
│  │  - Volume: /appdata/.../uploads  │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Web UI Container (React/Nginx)  │  │
│  │  - Port: 3000                    │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Redis Container (Optional)      │  │
│  │  - Port: 6379                    │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Backup Service (Optional)       │  │
│  │  - Automated daily backups       │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Network Flow

```
Atlas App (iPad)
    ↓
    → HTTP/HTTPS (LAN)
    ↓
Unraid Server (192.168.1.XXX)
    ↓
    ├─→ Web UI (Port 3000)
    │      ↓
    │      → Nginx serves React SPA
    │
    └─→ API (Port 3001)
           ↓
           ├─→ Node.js/Express
           ├─→ PostgreSQL Database
           └─→ Redis Cache (optional)
```

## Environment Configuration

### Required Environment Variables

```bash
# Database
DB_PASSWORD=<strong-password>              # Required

# Security
JWT_SECRET=<32-char-secret>                # Required
API_KEY=<api-key-for-atlas>                # Required for Atlas

# Network
UNRAID_IP=192.168.1.XXX                    # Your server IP
API_URL=http://192.168.1.XXX:3001          # API endpoint
```

### Optional Environment Variables

```bash
# Atlas Integration
ATLAS_INTEGRATION=true
ATLAS_CALLBACK_URL=atlas://callback/heating-design
ATLAS_WEBHOOK_URL=http://atlas-server/webhook

# Performance
API_WORKERS=4
DB_MAX_CONNECTIONS=50

# Features
ENABLE_WEBHOOKS=false
ENABLE_REDIS_CACHE=true
LOG_LEVEL=info
```

See [.env.example](unraid/.env.example) for complete list.

## Storage Layout

### Persistent Data on Unraid

```
/mnt/user/appdata/heating-design/
├── db/                    # PostgreSQL data
├── uploads/               # Floor plans, documents
├── exports/               # Generated PDFs
├── temp/                  # Temporary files
├── logs/                  # Application logs
├── redis/                 # Redis cache (optional)
├── backups/               # Database backups
├── docker-compose.yml     # Compose configuration
└── .env                   # Environment variables
```

### Storage Requirements

- **Minimum:** 5GB
- **Recommended:** 10GB
- **With backups:** 20GB+

Storage grows with:
- Uploaded floor plans
- Generated PDFs
- Database size
- Log retention
- Backup retention

## Port Mapping

| Service | Internal Port | External Port | Protocol |
|---------|--------------|---------------|----------|
| Web UI | 80 | 3000 | HTTP |
| API | 3001 | 3001 | HTTP |
| Database | 5432 | 5433 | PostgreSQL |
| Redis | 6379 | 6379 | Redis |

**Firewall Configuration:**

For Atlas integration, ensure ports 3000 and 3001 are accessible from your local network.

## Backup Strategy

### Automated Backups (Included)

The deployment includes an automated backup container:

- **Frequency:** Daily at midnight
- **Retention:**
  - 7 daily backups
  - 4 weekly backups
  - 6 monthly backups
- **Location:** `/mnt/user/appdata/heating-design/backups/`

### Manual Backup

```bash
# Database backup
docker exec heating_design_db pg_dump -U heating_admin heating_design > backup.sql

# Full backup (all data)
tar -czf heating-design-backup.tar.gz /mnt/user/appdata/heating-design/
```

### Restore from Backup

```bash
# Stop services
docker compose down

# Restore database
cat backup.sql | docker exec -i heating_design_db psql -U heating_admin -d heating_design

# Restart services
docker compose up -d
```

## Security Considerations

### Best Practices

1. **Strong Passwords**
   - Use `openssl rand -hex 32` for secrets
   - Never commit `.env` to version control
   - Rotate API keys regularly

2. **Network Security**
   - Use HTTPS with reverse proxy
   - Restrict API access to local network
   - Consider VPN for remote access

3. **Database Security**
   - Database not exposed externally (port 5433 for local access only)
   - Regular backups
   - Encrypted backups for offsite storage

4. **Container Security**
   - Images run as non-root users
   - Minimal attack surface
   - Regular updates

### Recommended: Reverse Proxy with SSL

Use Nginx Proxy Manager or Traefik:

```yaml
# Example Traefik configuration (already in docker-compose.yml)
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.heating-web.rule=Host(`heating.yourdomain.com`)"
  - "traefik.http.routers.heating-web.tls=true"
  - "traefik.http.routers.heating-web.tls.certresolver=letsencrypt"
```

## Monitoring & Maintenance

### Health Checks

All containers include health checks:

```bash
# Check container health
docker ps

# API health endpoint
curl http://YOUR_UNRAID_IP:3001/health

# Database health
docker exec heating_design_db pg_isready
```

### Logs

```bash
# View all logs
docker compose logs -f

# View specific service
docker compose logs -f heating_api

# Last 100 lines
docker compose logs --tail=100 heating_api
```

### Resource Monitoring

```bash
# Container resource usage
docker stats

# Disk usage
docker system df

# Cleanup unused resources
docker system prune -a
```

### Updates

```bash
# 1. Backup first!
docker exec heating_design_db pg_dump > backup-before-update.sql

# 2. Rebuild images
./deployment/scripts/build-and-deploy.sh

# 3. Deploy new version
docker compose up -d --force-recreate

# 4. Verify
curl http://YOUR_UNRAID_IP:3001/health
```

## Troubleshooting

### Common Issues

**1. Container won't start**
```bash
docker compose logs <service-name>
docker compose config  # Validate configuration
```

**2. Database connection errors**
```bash
docker exec heating_design_db psql -U heating_admin -d heating_design -c "SELECT 1"
```

**3. API not responding**
```bash
docker exec heating_design_api wget -O- http://localhost:3001/health
```

**4. Web UI blank page**
```bash
docker exec heating_design_web nginx -t
docker exec heating_design_web ls -la /usr/share/nginx/html/
```

See [Deployment Guide](unraid/DEPLOYMENT_GUIDE.md#troubleshooting) for detailed troubleshooting.

## Performance Tuning

### For Better Performance

1. **Use Unraid Cache Drive**
   ```bash
   # Move appdata to cache for faster I/O
   mv /mnt/user/appdata/heating-design /mnt/cache/appdata/
   ```

2. **PostgreSQL Tuning**
   - Already configured for NAS environment
   - Adjust in docker-compose.yml if needed

3. **Enable Redis Caching**
   - Uncomment Redis service in docker-compose.yml
   - Reduces database load

4. **API Workers**
   - Adjust `API_WORKERS` in `.env`
   - Default: 4 workers

## Development vs Production

### Development Setup

For local development, see the main project README.

### Production Deployment

This deployment is production-ready with:
- ✓ Health checks
- ✓ Automatic restarts
- ✓ Automated backups
- ✓ Resource limits
- ✓ Logging
- ✓ Security hardening

## Integration with Other Systems

### Atlas App (iOS)

See [Atlas Integration Guide](atlas-integration/README.md)

### Hail Mary Project (Unraid)

Both applications can run on the same Unraid server:

```yaml
# Can share network or use separate networks
networks:
  - heating_design_network
  - hail_mary_network  # If needed
```

### Third-Party Integrations

API supports:
- Webhooks
- REST API
- JWT authentication
- API key authentication

## FAQ

**Q: Can I run this on Docker (not Unraid)?**
A: Yes, the docker-compose.yml works on any Docker host. Just adjust paths.

**Q: Can I use MySQL instead of PostgreSQL?**
A: Not recommended. The schema uses PostgreSQL-specific features.

**Q: How do I add HTTPS?**
A: Use a reverse proxy like Nginx Proxy Manager or Traefik.

**Q: Can Atlas access this over the internet?**
A: Yes, but use VPN or reverse proxy with authentication for security.

**Q: What if I need to scale?**
A: The API can scale horizontally. Add load balancer and multiple API containers.

## Support & Resources

- **GitHub Issues:** [Link to issues]
- **Documentation:** [Link to docs]
- **Unraid Forums:** https://forums.unraid.net/
- **Docker Docs:** https://docs.docker.com/

## License

[Your License]

---

**Ready to deploy?** Start with [QUICKSTART.md](QUICKSTART.md)
