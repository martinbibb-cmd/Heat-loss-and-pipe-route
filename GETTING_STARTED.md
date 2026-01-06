# Getting Started with Heating Design Application

Complete guide to get the Heating Design application running locally or on Unraid.

## Table of Contents

1. [Quick Start (Unraid)](#quick-start-unraid)
2. [Local Development](#local-development)
3. [Configuration](#configuration)
4. [Running the Application](#running-the-application)
5. [Testing](#testing)
6. [Building for Production](#building-for-production)

---

## Quick Start (Unraid)

**Deploy in 5 minutes:**

```bash
git clone https://github.com/martinbibb-cmd/Heat-loss-and-pipe-route.git
cd Heat-loss-and-pipe-route
./deployment/scripts/build-and-deploy.sh --unraid-ip YOUR_UNRAID_IP
```

See [deployment/QUICKSTART.md](deployment/QUICKSTART.md) for detailed instructions.

---

## Local Development

### Prerequisites

- **Node.js** 20+ and npm 9+
- **PostgreSQL** 15+
- **Docker** (optional, for database)
- **Git**

### 1. Clone Repository

```bash
git clone https://github.com/martinbibb-cmd/Heat-loss-and-pipe-route.git
cd Heat-loss-and-pipe-route
```

### 2. Install Dependencies

```bash
npm install
```

This installs dependencies for all packages (monorepo with workspaces).

### 3. Set Up Database

**Option A: Using Docker (Recommended)**

```bash
docker run -d \
  --name heating-postgres \
  -e POSTGRES_USER=heating_admin \
  -e POSTGRES_PASSWORD=your_password \
  -e POSTGRES_DB=heating_design \
  -p 5432:5432 \
  postgres:15-alpine
```

**Option B: Local PostgreSQL**

Create database manually:

```sql
CREATE DATABASE heating_design;
CREATE USER heating_admin WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE heating_design TO heating_admin;
```

### 4. Configure Environment

Create `.env` file in the root:

```bash
cp .env.example .env
```

Edit `.env`:

```env
# Database
DATABASE_URL="postgresql://heating_admin:your_password@localhost:5432/heating_design"

# Security
JWT_SECRET="your-super-secret-jwt-key-at-least-32-characters"
API_KEY="your-api-key-for-atlas-integration"

# Server
PORT=3001
NODE_ENV=development

# CORS
ALLOWED_ORIGINS="http://localhost:3000,http://localhost:5173"
```

### 5. Run Database Migrations

```bash
npm run db:generate    # Generate Prisma client
npm run db:migrate     # Run migrations
```

### 6. Start Development Servers

**Option A: All services at once**

```bash
npm run dev
```

This starts:
- API server on http://localhost:3001
- Web UI on http://localhost:3000

**Option B: Individual services**

```bash
# Terminal 1 - API
npm run dev:api

# Terminal 2 - Web UI
npm run dev:web
```

### 7. Verify Setup

- **API Health:** http://localhost:3001/health
- **Web UI:** http://localhost:3000
- **Prisma Studio:** `npm run db:studio` (http://localhost:5555)

---

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DATABASE_URL` | PostgreSQL connection string | - | ✅ |
| `JWT_SECRET` | Secret for JWT tokens | - | ✅ |
| `API_KEY` | API key for Atlas integration | - | ⚠️ |
| `PORT` | API server port | 3001 | ❌ |
| `NODE_ENV` | Environment (development/production) | development | ❌ |
| `ALLOWED_ORIGINS` | CORS allowed origins | * | ❌ |
| `LOG_LEVEL` | Logging level | info | ❌ |

### Generate Secrets

```bash
# Generate JWT secret
openssl rand -hex 32

# Generate API key
openssl rand -hex 24

# Generate database password
openssl rand -base64 32
```

---

## Running the Application

### Development Mode

```bash
npm run dev
```

Features:
- Hot reload for API and Web UI
- Source maps enabled
- Detailed error messages
- Request logging

### Production Mode

```bash
# Build all packages
npm run build

# Start API
cd packages/api
npm start

# Serve Web UI with nginx or similar
cd packages/web
npx serve -s dist
```

---

## Testing

### Run All Tests

```bash
npm test
```

### API Tests Only

```bash
npm run test:api
```

### Web UI Tests Only

```bash
npm run test:web
```

### Test Coverage

```bash
npm run test:coverage
```

### Watch Mode

```bash
npm run test:watch
```

---

## Building for Production

### Build All Packages

```bash
npm run build
```

Output:
- API: `packages/api/dist/`
- Web UI: `packages/web/dist/`

### Build Docker Images

```bash
# API image
docker build -f deployment/docker/api/Dockerfile -t heating-design-api .

# Web UI image
docker build -f deployment/docker/web/Dockerfile -t heating-design-web .
```

### Deploy with Docker Compose

```bash
cd deployment/unraid
cp .env.example .env
# Edit .env with your configuration
docker compose up -d
```

---

## Project Structure

```
Heat-loss-and-pipe-route/
├── packages/
│   ├── api/                    # Backend API
│   │   ├── src/
│   │   │   ├── config/         # Configuration
│   │   │   ├── routes/         # API routes
│   │   │   ├── services/       # Business logic
│   │   │   ├── middleware/     # Express middleware
│   │   │   ├── utils/          # Utilities
│   │   │   └── server.ts       # Entry point
│   │   └── package.json
│   │
│   └── web/                    # Frontend React app
│       ├── src/
│       │   ├── components/     # React components
│       │   ├── pages/          # Page components
│       │   ├── services/       # API clients
│       │   └── main.tsx        # Entry point
│       └── package.json
│
├── prisma/
│   └── schema.prisma           # Database schema
│
├── deployment/
│   ├── unraid/                 # Unraid deployment
│   ├── docker/                 # Dockerfiles
│   └── scripts/                # Build scripts
│
├── .github/
│   └── workflows/              # CI/CD pipelines
│
├── package.json                # Root package.json
└── README.md                   # Main documentation
```

---

## Common Tasks

### Add a New API Route

1. Create route file in `packages/api/src/routes/`
2. Import and register in `server.ts`
3. Test with curl or Postman

### Add a New Database Model

1. Edit `prisma/schema.prisma`
2. Run `npm run db:migrate`
3. Prisma Client auto-updates

### Update Dependencies

```bash
npm update                 # Update all packages
npm outdated              # Check for outdated packages
npm audit                 # Security audit
npm audit fix             # Auto-fix vulnerabilities
```

### View Logs

```bash
# Development
npm run dev               # Logs to console

# Production (Docker)
docker compose logs -f    # Follow logs
docker compose logs api   # API logs only
docker compose logs web   # Web logs only
```

### Database Management

```bash
npm run db:studio         # Open Prisma Studio
npm run db:migrate        # Run migrations
npm run db:generate       # Regenerate Prisma Client
```

---

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 3001
lsof -i :3001

# Kill process
kill -9 <PID>
```

### Database Connection Error

```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Test connection
psql -h localhost -U heating_admin -d heating_design
```

### Build Errors

```bash
# Clean install
rm -rf node_modules package-lock.json
npm install

# Clear Prisma cache
rm -rf node_modules/.prisma
npm run db:generate
```

### Hot Reload Not Working

```bash
# Restart dev server
npm run dev

# Clear Vite cache (Web UI)
rm -rf packages/web/.vite
```

---

## Next Steps

- 📖 Read [API Documentation](docs/API.md)
- 🚀 Deploy to [Unraid](deployment/QUICKSTART.md)
- 📱 Integrate with [Atlas App](deployment/atlas-integration/README.md)
- 🔐 Set up [HTTPS](deployment/HTTPS_SETUP.md)
- 🔄 Configure [CI/CD](.github/workflows/)

---

## Support

- **Issues:** https://github.com/martinbibb-cmd/Heat-loss-and-pipe-route/issues
- **Documentation:** [README.md](README.md)
- **Deployment:** [deployment/README.md](deployment/README.md)

---

**Happy coding! 🎉**
