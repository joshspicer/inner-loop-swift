# InnerLoop Service

A dockerized backend service for processing iOS app logs and errors with a plugin-based architecture.

## Features

- **Batch Log Processing**: Receives and stores batched logs from iOS apps
- **Error Tracking**: Captures and stores error reports with full context
- **Plugin System**: Extensible architecture with TypeScript-based plugins and lifecycle hooks
- **GitHub Integration**: Automatically create GitHub issues for errors and user reports
- **Admin UI**: Web-based admin interface for managing clients, viewing logs, and configuring plugins
- **Client Authentication**: Secure client registration with shared secrets
- **SQLite Database**: Persistent storage of all logs and errors
- **RESTful API**: Easy-to-use endpoints for querying and managing data
- **Docker Support**: Easy deployment with Docker and Docker Compose
- **Health Checks**: Built-in health monitoring
- **TypeScript**: Fully typed codebase for better maintainability

## Quick Start

### Using Docker Compose (Recommended)

1. **Copy environment file**:
```bash
cp .env.example .env
```

2. **Edit `.env`** and configure as needed:
```bash
# Server Configuration
PORT=7990
DATABASE_PATH=./data/innerloop.db
ADMIN_PASSWORD=your-secure-password

# Optional: GitHub Plugin (can also configure via Admin UI)
PLUGIN_GITHUB_TOKEN=ghp_your_token_here
PLUGIN_GITHUB_OWNER=your-github-username
PLUGIN_GITHUB_REPO=your-repo-name
```

3. **Start the service**:
```bash
docker-compose up -d
```

The service will be available at `http://localhost:7990`
Admin UI will be at `http://localhost:7990/admin`

### Using Pre-built Docker Image

Pre-built Docker images are automatically published to GitHub Container Registry on every push to main.

```bash
# Pull and run the latest image
docker run -d \
  -p 7990:7990 \
  -v innerloop-data:/app/data \
  -e ADMIN_PASSWORD=your-password \
  --name innerloop-service \
  ghcr.io/joshspicer/innerloop:latest
```

### Local Development

```bash
# Install dependencies
npm install

# Copy and configure environment
cp .env.example .env
# Edit .env as needed

# Start the server
npm start

# Or with auto-reload
npm run dev
```

## Admin UI

The Admin UI provides a web-based interface for managing InnerLoop:

### Accessing Admin UI

1. Navigate to `http://localhost:7990/admin`
2. Login with your admin password (default: `admin`)

### Features

#### Clients Tab
- View all registered clients
- Add new client applications
- Edit client settings (name, secret, enabled status)
- Delete clients

#### Logs Tab
- View all errors with filtering by app
- View all log batches with user messages
- Detailed view of individual errors and batches
- Filter by environment (development, staging, production)

#### Plugins Tab
- Configure and enable/disable plugins
- Built-in GitHub plugin configuration
- View plugin documentation

## API Endpoints

### Health Check
```bash
GET /health
```
Returns service health status.

### Client Authentication

All API endpoints (except health and admin) require client authentication using `X-App-Id` and `X-Shared-Secret` headers.

### Submit Error
```bash
POST /api/errors
X-App-Id: com.example.myapp
X-Shared-Secret: your-shared-secret
Content-Type: application/json

{
  "message": "Error description",
  "stackTrace": "Stack trace string",
  "timestamp": "2026-01-12T19:00:00Z",
  "environment": "production",
  "appVersion": "1.0.0",
  "metadata": {
    "userId": "12345",
    "deviceModel": "iPhone 14"
  }
}
```

### Submit Log Batch
```bash
POST /api/batch
X-App-Id: com.example.myapp
X-Shared-Secret: your-shared-secret
Content-Type: application/json

{
  "userMessage": "App crashed when tapping save button",
  "timestamp": "2026-01-12T19:00:00Z",
  "environment": "production",
  "appVersion": "1.0.0",
  "sessionId": "unique-session-id",
  "metadata": {
    "deviceModel": "iPhone 14"
  },
  "logs": [
    {
      "message": "User tapped save button",
      "level": "INFO",
      "timestamp": "2026-01-12T18:59:58Z",
      "file": "ViewController.swift",
      "function": "saveButtonTapped",
      "line": 42,
      "category": "UI"
    },
    {
      "message": "Validation failed",
      "level": "ERROR",
      "timestamp": "2026-01-12T18:59:59Z",
      "file": "DataValidator.swift",
      "function": "validate",
      "line": 15,
      "category": "Validation"
    }
  ]
}
```

### Query Errors
```bash
GET /api/errors?limit=50
```
Returns the most recent errors.

### Query Log Batches
```bash
GET /api/batches?limit=50
```
Returns the most recent log batches.

### Get Batch Details
```bash
GET /api/batches/:id
```
Returns a specific batch with all its logs.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `7990` | Server port |
| `DATABASE_PATH` | `./data/innerloop.db` | SQLite database path |
| `ADMIN_PASSWORD` | `admin` | Admin UI password |
| `PLUGIN_GITHUB_TOKEN` | - | GitHub personal access token |
| `PLUGIN_GITHUB_OWNER` | - | GitHub repository owner |
| `PLUGIN_GITHUB_REPO` | - | GitHub repository name |
| `PLUGIN_GITHUB_ASSIGNEES` | - | Comma-separated list of GitHub usernames |
| `PLUGIN_GITHUB_LABELS` | - | Comma-separated list of labels |
| `PLUGIN_GITHUB_CREATE_ISSUE_ON_ERROR` | `false` | Create issue for every error |
| `PLUGIN_GITHUB_CREATE_ISSUE_ON_BATCH` | `true` | Create issue for user reports |

## Plugin System

The service includes a powerful plugin system for extending functionality. Plugins can hook into error and batch lifecycle events.

### Available Hooks

- `onInit` - Plugin initialization
- `onErrorReceived` - When error is received
- `onErrorStored` - After error is saved to database
- `onBatchReceived` - When log batch is received
- `onBatchStored` - After batch is saved to database
- `onError` - When any hook throws an error

### GitHub Plugin

The built-in GitHub plugin automatically creates issues for errors and user reports.

#### Configuration via Admin UI (Recommended)

1. Go to Admin → Plugins → Configure Plugin
2. Select "GitHub Plugin"
3. Enter your GitHub Personal Access Token
4. Enter repository owner and name
5. Configure labels, assignees, and when to create issues

#### Configuration via Environment Variables

```bash
PLUGIN_GITHUB_TOKEN=ghp_your_personal_access_token
PLUGIN_GITHUB_OWNER=your-username
PLUGIN_GITHUB_REPO=your-repo
PLUGIN_GITHUB_ASSIGNEES=username1,username2
PLUGIN_GITHUB_LABELS=bug,innerloop
PLUGIN_GITHUB_CREATE_ISSUE_ON_ERROR=false
PLUGIN_GITHUB_CREATE_ISSUE_ON_BATCH=true
```

#### Example Issue

When a user reports an issue via shake-to-send, the plugin creates:

```markdown
Title: [InnerLoop User Report] App crashed when tapping save button

## User Report
**App ID:** com.example.myapp
**Environment:** production
**App Version:** 1.2.3

### User Description
> App crashed when tapping save button

### Error Logs
1. [2026-01-12T19:59:58Z] Validation failed: email is required
   - Location: DataValidator.swift:15 in validate

### Warning Logs
1. [2026-01-12T19:59:50Z] Memory usage above 80%

### Recent Activity
1. [2026-01-12T19:59:45Z] User navigated to settings
2. [2026-01-12T19:59:55Z] User tapped save button
```

For complete plugin documentation, see [PLUGINS.md](PLUGINS.md).

## iOS Library Configuration

Configure your iOS app to send logs to this service:

```swift
import InnerLoop

// Configure endpoint (can be done dynamically)
let config = InnerLoopConfiguration(
    errorReportingURI: "http://your-server.com:7990/api/errors",
    batchReportingURI: "http://your-server.com:7990/api/batch",
    appId: "com.example.myapp",
    sharedSecret: "your-client-secret",
    enableShakeGesture: true,
    environment: "production",
    appVersion: "1.0.0",
    maxBufferSize: 1000,
    batchInterval: 300
)

InnerLoop.shared.initialize(with: config)
```

## Database Schema

### Tables

**clients**
- `app_id`: Primary key, client identifier
- `app_name`: Display name
- `shared_secret`: Authentication secret
- `enabled`: Whether client is active
- `created_at`, `updated_at`: Timestamps

**errors**
- `id`: Auto-incrementing primary key
- `app_id`: Foreign key to clients
- `message`: Error message
- `stack_trace`: Stack trace
- `timestamp`: When error occurred
- `environment`: App environment
- `app_version`: App version
- `metadata`: JSON metadata
- `created_at`: When stored

**log_batches**
- `id`: Auto-incrementing primary key
- `app_id`: Foreign key to clients
- `user_message`: User's description of the issue
- `timestamp`: When batch was created
- `environment`: App environment
- `app_version`: App version
- `metadata`: JSON metadata
- `log_count`: Number of logs in batch
- `session_id`: Unique identifier for the app session
- `created_at`: When stored

**batch_logs**
- `id`: Auto-incrementing primary key
- `batch_id`: Foreign key to log_batches
- `message`: Log message
- `level`: Log level (DEBUG, INFO, WARNING, ERROR)
- `timestamp`: When log was created
- `file`: Source file
- `function`: Function name
- `line`: Line number
- `category`: Log category

**plugin_configs**
- `id`: Auto-incrementing primary key
- `name`: Plugin identifier
- `config`: JSON configuration
- `enabled`: Whether plugin is active
- `created_at`, `updated_at`: Timestamps

## Production Deployment

### Security Considerations

1. **Use HTTPS**: Deploy behind a reverse proxy with SSL/TLS
2. **Strong Passwords**: Use secure admin and client secrets
3. **Rate Limiting**: Consider implementing rate limiting
4. **Network Security**: Restrict access to trusted networks/IPs
5. **Secrets Management**: Use secure secret storage (AWS Secrets Manager, etc.)

### Recommended Architecture

```
[iOS Apps] → [Load Balancer] → [InnerLoop Service] → [Database]
                                        ↓
                                   [GitHub API]
```

### Example nginx Configuration

```nginx
server {
    listen 443 ssl;
    server_name innerloop.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:7990;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Monitoring

### Health Check

The service includes a health check endpoint at `/health`:

```bash
curl http://localhost:7990/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2026-01-12T19:00:00.000Z"
}
```

### Docker Health Check

Docker Compose includes automatic health checks. Check status:

```bash
docker-compose ps
```

### Logs

View service logs:
```bash
# Docker Compose
docker-compose logs -f innerloop-service

# Docker
docker logs -f innerloop-service
```

## Backup and Restore

### Backup Database

```bash
# Copy from Docker volume
docker run --rm -v innerloop-data:/data -v $(pwd):/backup alpine \
  cp /data/innerloop.db /backup/innerloop-backup.db
```

### Restore Database

```bash
# Copy to Docker volume
docker run --rm -v innerloop-data:/data -v $(pwd):/backup alpine \
  cp /backup/innerloop-backup.db /data/innerloop.db
```

## Troubleshooting

### Service won't start

1. Check if port 7990 is available:
```bash
lsof -i :7990
```

2. Check Docker logs:
```bash
docker-compose logs innerloop-service
```

### Client authentication failing

1. Verify client is registered via Admin UI
2. Check `X-App-Id` and `X-Shared-Secret` headers match exactly
3. Ensure client is enabled in Admin UI

### GitHub issues not being created

1. Verify GitHub plugin is configured via Admin UI → Plugins
2. Check GitHub token has `repo` scope
3. Check service logs for errors:
```bash
docker-compose logs -f innerloop-service
```

### Database issues

1. Check database file permissions:
```bash
docker-compose exec innerloop-service ls -la /app/data/
```

2. Reset database (CAUTION: deletes all data):
```bash
docker-compose down
docker volume rm innerloop-data
docker-compose up -d
```

## Development

### Running Tests

```bash
npm install
npm test
```

### Project Structure

```
service/
├── src/
│   ├── server.ts           # Main Express server
│   ├── plugin-system.ts    # Plugin architecture
│   ├── auth.ts             # Client authentication
│   └── plugins/
│       └── github-plugin.ts  # GitHub integration
├── public/
│   ├── index.html          # Admin UI HTML
│   ├── app.js              # Admin UI JavaScript
│   └── style.css           # Admin UI Styles
├── package.json            # Dependencies
├── Dockerfile              # Docker image
├── docker-compose.yml      # Docker Compose config
├── .env.example            # Example environment
├── PLUGINS.md              # Plugin documentation
└── README.md               # This file
```

## License

MIT

## Support

For issues or questions, please open an issue on GitHub.
