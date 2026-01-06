# HTTPS/SSL Configuration for Heating Design

Multiple options for securing your Heating Design application with HTTPS.

## Option 1: Traefik (Recommended for Unraid)

Traefik is already configured in the docker-compose.yml with labels. Here's how to enable it.

### Setup Traefik on Unraid

1. **Install Traefik Container**

Create `/mnt/user/appdata/traefik/traefik.yml`:

```yaml
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik_network

log:
  level: INFO
```

2. **Create Traefik Docker Compose**

Create `/mnt/user/appdata/traefik/docker-compose.yml`:

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Traefik dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.yourdomain.com`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"

networks:
  traefik_network:
    external: true
```

3. **Create Traefik Network**

```bash
docker network create traefik_network
```

4. **Start Traefik**

```bash
cd /mnt/user/appdata/traefik
docker compose up -d
```

### Update Heating Design to Use Traefik

Modify `/mnt/user/appdata/heating-design/docker-compose.yml`:

```yaml
# Add to heating_web service:
heating_web:
  # ... existing config ...
  networks:
    - heating_network
    - traefik_network
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.heating-web.rule=Host(`heating.yourdomain.com`)"
    - "traefik.http.routers.heating-web.entrypoints=websecure"
    - "traefik.http.routers.heating-web.tls.certresolver=letsencrypt"
    - "traefik.http.services.heating-web.loadbalancer.server.port=80"
    - "traefik.docker.network=traefik_network"

# Add to heating_api service:
heating_api:
  # ... existing config ...
  networks:
    - heating_network
    - traefik_network
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.heating-api.rule=Host(`heating-api.yourdomain.com`)"
    - "traefik.http.routers.heating-api.entrypoints=websecure"
    - "traefik.http.routers.heating-api.tls.certresolver=letsencrypt"
    - "traefik.http.services.heating-api.loadbalancer.server.port=3001"
    - "traefik.docker.network=traefik_network"

networks:
  heating_network:
    # ... existing config ...
  traefik_network:
    external: true
```

**Restart services:**

```bash
cd /mnt/user/appdata/heating-design
docker compose down
docker compose up -d
```

**Access:**
- Web UI: `https://heating.yourdomain.com`
- API: `https://heating-api.yourdomain.com`

---

## Option 2: Nginx Proxy Manager (Easiest for Beginners)

### Install Nginx Proxy Manager

1. **Deploy via Unraid Community Apps**
   - Search for "Nginx Proxy Manager"
   - Install with default settings

2. **Or use Docker Compose**

Create `/mnt/user/appdata/nginx-proxy-manager/docker-compose.yml`:

```yaml
version: '3.8'

services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "81:81"  # Admin interface
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    environment:
      DB_SQLITE_FILE: "/data/database.sqlite"
```

3. **Start Nginx Proxy Manager**

```bash
cd /mnt/user/appdata/nginx-proxy-manager
docker compose up -d
```

### Configure Proxy Hosts

1. **Access Admin Interface**: `http://YOUR_UNRAID_IP:81`
   - Default login: `admin@example.com` / `changeme`
   - Change password immediately!

2. **Add Proxy Host for Web UI**
   - Domain: `heating.yourdomain.com`
   - Forward Hostname: `YOUR_UNRAID_IP`
   - Forward Port: `3000`
   - Enable "Websockets Support"
   - SSL Tab: Request Let's Encrypt SSL
   - Enable "Force SSL"

3. **Add Proxy Host for API**
   - Domain: `heating-api.yourdomain.com`
   - Forward Hostname: `YOUR_UNRAID_IP`
   - Forward Port: `3001`
   - Enable "Websockets Support"
   - SSL Tab: Request Let's Encrypt SSL
   - Enable "Force SSL"

**Update Atlas App Configuration:**

```swift
static let baseURL = "https://heating-api.yourdomain.com"
```

---

## Option 3: Self-Signed Certificates (Local Network Only)

For local network without public domain:

### Generate Self-Signed Certificate

```bash
cd /mnt/user/appdata/heating-design

# Generate certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/heating.key \
  -out ssl/heating.crt \
  -subj "/C=GB/ST=England/L=London/O=Heating Design/CN=heating.local"
```

### Update Nginx Configuration

Modify `deployment/docker/web/nginx.conf`:

```nginx
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;

    ssl_certificate /etc/nginx/ssl/heating.crt;
    ssl_certificate_key /etc/nginx/ssl/heating.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # ... rest of config ...
}
```

### Update Docker Compose

```yaml
heating_web:
  # ... existing config ...
  volumes:
    - /mnt/user/appdata/heating-design/ssl:/etc/nginx/ssl:ro
  ports:
    - "3000:80"
    - "3443:443"
```

**Access:**
- Web UI: `https://YOUR_UNRAID_IP:3443` (certificate warning expected)
- API: `http://YOUR_UNRAID_IP:3001` (keep HTTP for API)

---

## Option 4: Cloudflare Tunnel (No Port Forwarding)

For remote access without opening ports:

### Install Cloudflared

```bash
docker run -d \
  --name cloudflared \
  --restart unless-stopped \
  cloudflare/cloudflared:latest \
  tunnel --no-autoupdate run \
  --token YOUR_CLOUDFLARE_TUNNEL_TOKEN
```

### Setup Steps

1. **Create Cloudflare Account** (free)
2. **Add Domain** to Cloudflare
3. **Create Tunnel** in Zero Trust Dashboard
4. **Configure Public Hostname**:
   - `heating.yourdomain.com` → `http://YOUR_UNRAID_IP:3000`
   - `heating-api.yourdomain.com` → `http://YOUR_UNRAID_IP:3001`
5. **Copy Tunnel Token** and use in docker command above

**Benefits:**
- No port forwarding required
- Free SSL certificates
- DDoS protection
- Access from anywhere

---

## Recommended Configuration by Use Case

### Local Network Only (Atlas on Same WiFi)
**Use:** Option 3 (Self-Signed Certificates) or no SSL
- Simplest setup
- No external dependencies
- Fast performance

### Local + Remote Access (No Public Domain)
**Use:** Option 4 (Cloudflare Tunnel)
- No port forwarding
- Free SSL
- Secure remote access

### Public Domain Available
**Use:** Option 1 (Traefik) or Option 2 (Nginx Proxy Manager)
- **Traefik**: More powerful, Docker-native, automatic cert renewal
- **Nginx Proxy Manager**: Easier GUI, beginner-friendly

---

## DNS Configuration

### For Public Domains

Add A records:
```
heating.yourdomain.com     → YOUR_PUBLIC_IP
heating-api.yourdomain.com → YOUR_PUBLIC_IP
```

### For Local Network Only

Add to `/etc/hosts` on devices (or configure in router):
```
192.168.1.100  heating.local
192.168.1.100  heating-api.local
```

---

## Testing HTTPS

```bash
# Test SSL connection
curl -I https://heating.yourdomain.com

# Check certificate
openssl s_client -connect heating.yourdomain.com:443 -servername heating.yourdomain.com

# Test API over HTTPS
curl https://heating-api.yourdomain.com/health
```

---

## Atlas App HTTPS Configuration

Update `HeatingAPIConfig.swift`:

```swift
struct HeatingAPIConfig {
    static let baseURL: String = {
        #if DEBUG
        return "http://192.168.1.100:3001"
        #else
        return "https://heating-api.yourdomain.com"
        #endif
    }()
}
```

---

## Security Recommendations

1. **Always use HTTPS for production**
2. **Keep certificates up to date** (Let's Encrypt auto-renews)
3. **Use strong SSL protocols** (TLS 1.2+)
4. **Enable HSTS** (HTTP Strict Transport Security)
5. **Configure CORS properly** for API
6. **Use VPN** for sensitive remote access

---

## Troubleshooting HTTPS

### Certificate Not Trusted

**Let's Encrypt:**
- Ensure ports 80/443 are accessible
- Check DNS points to correct IP
- Verify email in Traefik config

**Self-Signed:**
- Install certificate on client devices
- Or accept security warning

### Mixed Content Warnings

Update API URL in web UI to use HTTPS:
```javascript
const API_URL = process.env.VITE_API_URL || 'https://heating-api.yourdomain.com'
```

### CORS Errors

Add CORS headers in API:
```javascript
app.use(cors({
  origin: ['https://heating.yourdomain.com'],
  credentials: true
}))
```

---

**Choose the option that best fits your deployment scenario!**
