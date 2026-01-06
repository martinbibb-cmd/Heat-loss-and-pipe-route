# Heat Loss and Pipe Route Design Application

Professional heating system design tool with heat loss calculations, pipe routing, and project management.

## Overview

This application helps heating engineers and building professionals design efficient heating systems by:
- Calculating heat loss for individual rooms and entire buildings
- Designing optimal pipe routes
- Managing floor plans and project documentation
- Generating professional PDF reports
- Integrating with the Atlas iOS app for field surveys

## Architecture

The application consists of three main components:

```
┌─────────────────────────────────────┐
│     Heating Design System           │
├─────────────────────────────────────┤
│                                     │
│  ┌────────────────────────────┐    │
│  │  Web UI (React PWA)        │    │
│  │  - Floor plan viewer       │    │
│  │  - Project management      │    │
│  │  - Report generation       │    │
│  └────────────────────────────┘    │
│                                     │
│  ┌────────────────────────────┐    │
│  │  API (Node.js/Express)     │    │
│  │  - Heat loss calculations  │    │
│  │  - Pipe routing engine     │    │
│  │  - File processing         │    │
│  └────────────────────────────┘    │
│                                     │
│  ┌────────────────────────────┐    │
│  │  Database (PostgreSQL)     │    │
│  │  - Projects & floor plans  │    │
│  │  - Calculations & results  │    │
│  │  - User management         │    │
│  └────────────────────────────┘    │
└─────────────────────────────────────┘
         ▲
         │ HTTP/REST API
         │
┌────────────────────┐
│   Atlas App (iOS)  │
│   Field surveys &  │
│   data collection  │
└────────────────────┘
```

## Features

### Heat Loss Calculations
- Room-by-room heat loss analysis
- Transmission and ventilation loss calculations
- Design heat load determination
- U-value based calculations (walls, windows, floors, ceilings)
- Compliance with building regulations

### Pipe Route Design
- Optimal routing algorithms
- Material and sizing calculations
- Insulation recommendations
- Length and cost estimations

### Project Management
- Multi-project support
- Floor plan upload and management
- Client information tracking
- Project status workflow

### Reporting
- Professional PDF reports
- Heat loss summaries
- Equipment specifications
- Installation documentation

### Atlas Integration
- Import survey data from Atlas iOS app
- Automatic project creation from field surveys
- Bi-directional data synchronization
- API-based communication

## Deployment

### Recommended: Unraid NAS Deployment

This application is designed to run on your Unraid server for:
- 24/7 availability
- Reliable PostgreSQL database
- File upload storage
- Local network access from Atlas app

**Quick Start:**

```bash
git clone <repository-url>
cd Heat-loss-and-pipe-route
./deployment/scripts/build-and-deploy.sh --unraid-ip YOUR_UNRAID_IP
```

See **[Deployment Documentation](deployment/README.md)** for:
- [15-Minute Quick Start Guide](deployment/QUICKSTART.md)
- [Complete Deployment Guide](deployment/unraid/DEPLOYMENT_GUIDE.md)
- [Atlas Integration Guide](deployment/atlas-integration/README.md)

### Alternative: Docker Deployment

The application can run on any Docker host:

```bash
cd deployment/unraid
cp .env.example .env
# Edit .env with your configuration
docker compose up -d
```

## Technology Stack

### Frontend
- React 18+ with TypeScript
- Vite for build tooling
- Progressive Web App (PWA) support
- Offline-first architecture

### Backend
- Node.js 20+
- Express.js
- Prisma ORM
- PostgreSQL 15+

### Infrastructure
- Docker & Docker Compose
- Nginx for web serving
- Redis for caching (optional)
- Automated backups

## Development

### Prerequisites
- Node.js 20+
- Docker & Docker Compose
- PostgreSQL 15+ (or use Docker)
- Git

### Local Setup

```bash
# Clone repository
git clone <repository-url>
cd Heat-loss-and-pipe-route

# Install dependencies
npm install

# Set up environment
cp .env.example .env
# Edit .env with local configuration

# Start database
docker compose -f docker-compose.dev.yml up -d postgres

# Run database migrations
npx prisma migrate dev

# Start development server
npm run dev
```

### Project Structure

```
Heat-loss-and-pipe-route/
├── src/
│   ├── api/              # Backend API
│   │   ├── routes/       # API endpoints
│   │   ├── services/     # Business logic
│   │   └── utils/        # Utilities
│   ├── web/              # Frontend application
│   │   ├── components/   # React components
│   │   ├── pages/        # Page components
│   │   └── services/     # API clients
│   └── shared/           # Shared types & utilities
├── prisma/
│   ├── schema.prisma     # Database schema
│   └── migrations/       # Database migrations
├── deployment/           # Deployment configurations
│   ├── unraid/           # Unraid-specific files
│   ├── docker/           # Dockerfiles
│   ├── atlas-integration/# Atlas app integration
│   └── scripts/          # Automation scripts
└── docs/                 # Documentation
```

## API Documentation

### Key Endpoints

**Health Check:**
```
GET /health
```

**Projects:**
```
POST   /api/projects              # Create project
GET    /api/projects              # List projects
GET    /api/projects/:id          # Get project details
PUT    /api/projects/:id          # Update project
DELETE /api/projects/:id          # Delete project
```

**Calculations:**
```
POST   /api/projects/:id/calculate     # Trigger calculations
GET    /api/projects/:id/results       # Get results
```

**Atlas Integration:**
```
POST   /api/atlas/import          # Import Atlas survey data
GET    /api/atlas/status          # Check integration status
```

**Export:**
```
POST   /api/projects/:id/export/pdf    # Generate PDF report
```

See [API Documentation](docs/API.md) for complete reference.

## Atlas App Integration

The Heating Design API integrates seamlessly with the Atlas iOS app for field data collection.

**Integration Flow:**
1. Conduct building survey in Atlas app
2. Atlas sends survey data to Heating Design API
3. API creates project and calculates heat loss
4. Results returned to Atlas app
5. Professional PDF report generated

See [Atlas Integration Guide](deployment/atlas-integration/README.md) for:
- Swift code examples
- API configuration
- Data mapping
- Error handling
- Offline support

## Configuration

### Environment Variables

**Required:**
```bash
DATABASE_URL=postgresql://user:password@host:5432/heating_design
JWT_SECRET=your-secret-key
API_KEY=your-api-key
```

**Optional:**
```bash
PORT=3001
NODE_ENV=production
LOG_LEVEL=info
ATLAS_INTEGRATION=true
ENABLE_WEBHOOKS=false
```

See [.env.example](deployment/unraid/.env.example) for complete list.

## Testing

```bash
# Run unit tests
npm test

# Run integration tests
npm run test:integration

# Run E2E tests
npm run test:e2e

# Test coverage
npm run test:coverage
```

## Maintenance

### Backups

Automated daily backups are included in the deployment:
- Database backups to `/mnt/user/appdata/heating-design/backups/`
- 7 daily, 4 weekly, 6 monthly retention
- Manual backup: `docker exec heating_design_db pg_dump > backup.sql`

### Updates

```bash
# Pull latest code
git pull

# Rebuild images
./deployment/scripts/build-and-deploy.sh

# Apply database migrations
docker exec heating_design_api npx prisma migrate deploy
```

### Monitoring

```bash
# View logs
docker compose logs -f

# Check health
curl http://YOUR_UNRAID_IP:3001/health

# Monitor resources
docker stats
```

## Troubleshooting

**API not responding:**
```bash
docker compose logs heating_api
docker compose restart heating_api
```

**Database connection errors:**
```bash
docker exec heating_design_db pg_isready
docker compose restart heating_db
```

**Web UI blank page:**
```bash
docker compose logs heating_web
docker compose restart heating_web
```

See [Troubleshooting Guide](deployment/unraid/DEPLOYMENT_GUIDE.md#troubleshooting) for detailed solutions.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Roadmap

- [ ] Advanced pipe routing algorithms
- [ ] 3D visualization of pipe routes
- [ ] Integration with manufacturer catalogs
- [ ] Multi-zone heating systems
- [ ] Energy efficiency calculations
- [ ] Cloud sync for multi-device access
- [ ] Mobile app (React Native)

## License

[Your License]

## Support

- **Issues:** [GitHub Issues](link)
- **Documentation:** [Documentation Site](link)
- **Email:** support@yourdomain.com

## Acknowledgments

- Built for heating engineers and building professionals
- Complies with UK Building Regulations Part L
- Integrates with Atlas field survey application
- Designed for deployment on Unraid NAS

---

**Ready to deploy?** See [Quick Start Guide](deployment/QUICKSTART.md)

**Need Atlas integration?** See [Atlas Integration Guide](deployment/atlas-integration/README.md)
