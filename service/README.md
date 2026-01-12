# InnerLoop Service

A dockerized backend service for processing iOS app logs and errors with LLM-powered analysis.

## Features

- **Batch Log Processing**: Receives and stores batched logs from iOS apps
- **Error Tracking**: Captures and stores error reports with full context
- **LLM Integration**: Automatic analysis of errors and logs using OpenAI or Anthropic
- **SQLite Database**: Persistent storage of all logs and errors
- **RESTful API**: Easy-to-use endpoints for querying and managing data
- **Docker Support**: Easy deployment with Docker and Docker Compose
- **Health Checks**: Built-in health monitoring

## Quick Start

### Using Docker Compose (Recommended)

1. **Copy environment file**:
```bash
cp .env.example .env
```

2. **Edit `.env` and add your API keys** (optional, for LLM features):
```bash
# Enable LLM analysis (optional)
ENABLE_LLM=true
AUTO_ANALYZE_ERRORS=true

# Choose provider: openai or anthropic
LLM_PROVIDER=openai

# Add your API key
OPENAI_API_KEY=sk-your-key-here
# OR
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

3. **Start the service**:
```bash
docker-compose up -d
```

The service will be available at `http://localhost:3000`

### Using Docker

```bash
# Build the image
docker build -t innerloop-service .

# Run the container
docker run -d \
  -p 3000:3000 \
  -v innerloop-data:/app/data \
  --name innerloop-service \
  innerloop-service
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

## API Endpoints

### Health Check
```bash
GET /health
```
Returns service health status.

### Submit Error
```bash
POST /api/errors
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
Content-Type: application/json

{
  "userMessage": "App crashed when tapping save button",
  "timestamp": "2026-01-12T19:00:00Z",
  "environment": "production",
  "appVersion": "1.0.0",
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
      "line": 42
    },
    {
      "message": "Validation failed",
      "level": "ERROR",
      "timestamp": "2026-01-12T18:59:59Z",
      "file": "DataValidator.swift",
      "function": "validate",
      "line": 15
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

### Trigger LLM Analysis
```bash
POST /api/batches/:id/analyze
```
Triggers LLM analysis for a specific batch.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Server port |
| `DATABASE_PATH` | `./data/innerloop.db` | SQLite database path |
| `ENABLE_LLM` | `false` | Enable LLM analysis |
| `AUTO_ANALYZE_ERRORS` | `false` | Automatically analyze errors with LLM |
| `LLM_PROVIDER` | `openai` | LLM provider (`openai` or `anthropic`) |
| `OPENAI_API_KEY` | - | OpenAI API key |
| `OPENAI_MODEL` | `gpt-4` | OpenAI model to use |
| `ANTHROPIC_API_KEY` | - | Anthropic API key |
| `ANTHROPIC_MODEL` | `claude-3-5-sonnet-20241022` | Anthropic model to use |

## iOS Library Configuration

Configure your iOS app to send logs to this service:

```swift
import InnerLoop

let config = InnerLoopConfiguration(
    errorReportingURI: "http://your-server.com:3000/api/errors",
    enableShakeGesture: true,
    environment: "production",
    appVersion: "1.0.0",
    maxBufferSize: 1000,      // Buffer up to 1000 logs
    batchInterval: 300         // Send every 5 minutes
)

InnerLoop.shared.initialize(with: config)
```

## LLM Analysis

When enabled, the service automatically analyzes:

1. **Errors**: Provides root cause analysis, fix suggestions, and prevention strategies
2. **Log Batches with User Messages**: Analyzes the full context when users report issues

### Example Analysis Output

For an error, the LLM provides:
- Root cause analysis
- Immediate fix suggestions
- Prevention strategies
- Additional context needed

For a log batch with user message:
- Issue identification
- Root cause
- Step-by-step fix
- Testing recommendations
- Related issues found in logs

## Database Schema

### Tables

**errors**
- `id`: Auto-incrementing primary key
- `message`: Error message
- `stack_trace`: Stack trace
- `timestamp`: When error occurred
- `environment`: App environment
- `app_version`: App version
- `metadata`: JSON metadata
- `created_at`: When stored

**log_batches**
- `id`: Auto-incrementing primary key
- `user_message`: User's description of the issue
- `timestamp`: When batch was created
- `environment`: App environment
- `app_version`: App version
- `metadata`: JSON metadata
- `log_count`: Number of logs in batch
- `analyzed`: Whether LLM analysis was performed
- `analysis`: LLM analysis results
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

## Production Deployment

### Security Considerations

1. **Use HTTPS**: Deploy behind a reverse proxy with SSL/TLS
2. **Authentication**: Add API key authentication for production
3. **Rate Limiting**: Implement rate limiting to prevent abuse
4. **Network Security**: Restrict access to trusted networks/IPs
5. **Secrets Management**: Use secure secret storage (AWS Secrets Manager, etc.)

### Recommended Architecture

```
[iOS Apps] → [Load Balancer] → [InnerLoop Service] → [Database]
                                        ↓
                                   [LLM API]
```

### Example nginx Configuration

```nginx
server {
    listen 443 ssl;
    server_name innerloop.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:3000;
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
curl http://localhost:3000/health
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

1. Check if port 3000 is available:
```bash
lsof -i :3000
```

2. Check Docker logs:
```bash
docker-compose logs innerloop-service
```

### LLM Analysis not working

1. Verify API key is set:
```bash
docker-compose exec innerloop-service env | grep API_KEY
```

2. Check LLM is enabled:
```bash
docker-compose exec innerloop-service env | grep ENABLE_LLM
```

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
# Install dev dependencies
npm install

# Run tests (when available)
npm test
```

### Project Structure

```
service/
├── server.js           # Main server application
├── llm-provider.js     # LLM integration module
├── package.json        # Node.js dependencies
├── Dockerfile          # Docker image definition
├── docker-compose.yml  # Docker Compose configuration
├── .env.example        # Example environment variables
└── README.md          # This file
```

## License

MIT

## Support

For issues or questions, please open an issue on GitHub.
