# Server Examples for InnerLoop

This directory contains example server implementations that can receive logs and errors from InnerLoop.

## Node.js/Express Example

A simple Express server that receives and logs errors:

```javascript
// server.js
const express = require('express');
const app = express();
const PORT = 7990;

app.use(express.json());

// Endpoint to receive errors
app.post('/api/errors', (req, res) => {
    const errorData = req.body;
    
    console.log('=== Error Report Received ===');
    console.log('Timestamp:', errorData.timestamp);
    console.log('Environment:', errorData.environment);
    console.log('App Version:', errorData.appVersion);
    console.log('Message:', errorData.message);
    console.log('Stack Trace:', errorData.stackTrace);
    console.log('Metadata:', JSON.stringify(errorData.metadata, null, 2));
    console.log('=============================\n');
    
    // Store in database, forward to monitoring service, etc.
    
    res.status(200).json({ status: 'received', id: Date.now() });
});

// Endpoint to receive logs
app.post('/api/logs', (req, res) => {
    const logData = req.body;
    
    console.log(`[${logData.level}] ${logData.message}`);
    
    res.status(200).json({ status: 'received' });
});

app.listen(PORT, () => {
    console.log(`InnerLoop server listening on port ${PORT}`);
});
```

### Setup and Run

```bash
npm init -y
npm install express
node server.js
```

### Test It

Use ngrok to expose your local server:
```bash
ngrok http 7990
```

Then use the ngrok URL in your InnerLoop configuration:
```swift
let config = InnerLoopConfiguration(
    errorReportingURI: "https://your-ngrok-url.ngrok.io/api/errors"
)
```

## Python/Flask Example

```python
# app.py
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

@app.route('/api/errors', methods=['POST'])
def receive_error():
    error_data = request.json
    
    print('=== Error Report Received ===')
    print(f"Timestamp: {error_data.get('timestamp')}")
    print(f"Environment: {error_data.get('environment')}")
    print(f"App Version: {error_data.get('appVersion')}")
    print(f"Message: {error_data.get('message')}")
    print(f"Stack Trace: {error_data.get('stackTrace')}")
    print(f"Metadata: {error_data.get('metadata')}")
    print('=============================\n')
    
    # Store in database, forward to monitoring service, etc.
    
    return jsonify({'status': 'received', 'id': int(datetime.now().timestamp())})

@app.route('/api/logs', methods=['POST'])
def receive_log():
    log_data = request.json
    
    print(f"[{log_data.get('level')}] {log_data.get('message')}")
    
    return jsonify({'status': 'received'})

if __name__ == '__main__':
    app.run(debug=True, port=7990)
```

### Setup and Run

```bash
pip install flask
python app.py
```

## Plugin Integration Example

InnerLoop includes a built-in plugin system. Instead of creating custom server examples, you can use the plugin system to extend functionality. Here's how plugins work:

### Using the Built-in Service with Plugins

The InnerLoop service (in the `service/` directory) includes a plugin architecture with lifecycle hooks:

```typescript
// Example: Creating a custom plugin
export const customPlugin: Plugin = {
  name: 'custom-plugin',
  hooks: {
    async onErrorReceived(error: ErrorReport) {
      // Process error when it arrives
      console.log('Error received:', error.message);

      // You can call any external service here:
      // - Send to Slack
      // - Call an LLM API for analysis
      // - Trigger webhooks
      // - Store in custom database
    },
    async onBatchStored(batch: LogBatch) {
      // Process log batch after it's stored
      console.log('User reported:', batch.userMessage);

      // Example: Forward to LLM for analysis
      if (process.env.ENABLE_LLM_ANALYSIS) {
        const analysis = await analyzeLogs(batch);
        console.log('Analysis:', analysis);
      }
    }
  }
};
```

### Example: LLM Analysis Plugin

If you want to integrate LLM analysis, create a custom plugin:

```typescript
// plugins/llm-analysis-plugin.ts
import { Plugin } from '../plugin-system';

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

async function analyzeWithLLM(errorData: any): Promise<string> {
  const prompt = `
Analyze this iOS app error and provide debugging suggestions:

Error Message: ${errorData.message}
Environment: ${errorData.environment}
App Version: ${errorData.appVersion}

Stack Trace:
${errorData.stackTrace}

Please provide:
1. Likely cause of the error
2. Suggested fixes
3. Additional information needed (if any)
`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'gpt-4',
      messages: [
        { role: 'system', content: 'You are an expert iOS developer.' },
        { role: 'user', content: prompt }
      ]
    })
  });

  const data = await response.json();
  return data.choices[0].message.content;
}

export const llmAnalysisPlugin: Plugin = {
  name: 'llm-analysis',
  hooks: {
    async onErrorReceived(error) {
      if (!OPENAI_API_KEY) return;

      console.log('Analyzing error with LLM...');
      const analysis = await analyzeWithLLM(error);
      console.log('=== LLM Analysis ===');
      console.log(analysis);
      console.log('===================');
    },
    async onBatchStored(batch) {
      if (!OPENAI_API_KEY || !batch.userMessage) return;

      console.log('Analyzing user report with LLM...');
      const analysis = await analyzeWithLLM({
        message: batch.userMessage,
        environment: batch.environment,
        appVersion: batch.appVersion,
        stackTrace: batch.logs
          .filter(log => log.level === 'ERROR')
          .map(log => `${log.message} at ${log.file}:${log.line}`)
          .join('\n')
      });
      console.log('=== LLM Analysis ===');
      console.log(analysis);
      console.log('===================');
    }
  }
};
```

### Enabling Your Custom Plugin

Add your plugin to the service:

```typescript
// In service/src/server.ts
import { llmAnalysisPlugin } from './plugins/llm-analysis-plugin';

pluginSystem.registerPlugin(llmAnalysisPlugin);
```

For complete plugin documentation and examples, see [../../service/PLUGINS.md](../../service/PLUGINS.md).

## Standalone Server Examples

## Database Storage Example

Store errors in a database for later analysis:

```javascript
// db-server.js
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const app = express();
const PORT = 7990;

app.use(express.json());

// Initialize SQLite database
const db = new sqlite3.Database('innerloop.db');

// Create tables
db.run(`
    CREATE TABLE IF NOT EXISTS errors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,
        environment TEXT,
        app_version TEXT,
        message TEXT,
        stack_trace TEXT,
        metadata TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
`);

db.run(`
    CREATE TABLE IF NOT EXISTS logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,
        level TEXT,
        message TEXT,
        file TEXT,
        function TEXT,
        line INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
`);

app.post('/api/errors', (req, res) => {
    const errorData = req.body;
    
    db.run(
        `INSERT INTO errors (timestamp, environment, app_version, message, stack_trace, metadata)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
            errorData.timestamp,
            errorData.environment,
            errorData.appVersion,
            errorData.message,
            errorData.stackTrace,
            JSON.stringify(errorData.metadata)
        ],
        function(err) {
            if (err) {
                console.error('Error storing error:', err);
                res.status(500).json({ error: 'Failed to store error' });
            } else {
                console.log(`Error stored with ID: ${this.lastID}`);
                res.status(200).json({ status: 'received', id: this.lastID });
            }
        }
    );
});

app.post('/api/logs', (req, res) => {
    const logData = req.body;
    
    db.run(
        `INSERT INTO logs (timestamp, level, message, file, function, line)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
            logData.timestamp,
            logData.level,
            logData.message,
            logData.file,
            logData.function,
            logData.line
        ],
        function(err) {
            if (err) {
                console.error('Error storing log:', err);
                res.status(500).json({ error: 'Failed to store log' });
            } else {
                res.status(200).json({ status: 'received', id: this.lastID });
            }
        }
    );
});

// Query endpoint to view errors
app.get('/api/errors', (req, res) => {
    db.all(
        'SELECT * FROM errors ORDER BY created_at DESC LIMIT 50',
        (err, rows) => {
            if (err) {
                res.status(500).json({ error: err.message });
            } else {
                res.json(rows);
            }
        }
    );
});

// Query endpoint to view logs
app.get('/api/logs', (req, res) => {
    const level = req.query.level;
    let query = 'SELECT * FROM logs';
    let params = [];
    
    if (level) {
        query += ' WHERE level = ?';
        params.push(level);
    }
    
    query += ' ORDER BY created_at DESC LIMIT 100';
    
    db.all(query, params, (err, rows) => {
        if (err) {
            res.status(500).json({ error: err.message });
        } else {
            res.json(rows);
        }
    });
});

app.listen(PORT, () => {
    console.log(`InnerLoop database server listening on port ${PORT}`);
    console.log(`View errors: http://localhost:${PORT}/api/errors`);
    console.log(`View logs: http://localhost:${PORT}/api/logs`);
});
```

### Setup and Run

```bash
npm install express sqlite3
node db-server.js
```

### View Stored Data

```bash
# View all errors
curl http://localhost:7990/api/errors

# View all logs
curl http://localhost:7990/api/logs

# View only error-level logs
curl http://localhost:7990/api/logs?level=ERROR
```

## Testing

You can test these servers with curl:

```bash
# Test error endpoint
curl -X POST http://localhost:7990/api/errors \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Test error",
    "stackTrace": "Line 1\nLine 2",
    "timestamp": "2026-01-09T20:00:00Z",
    "environment": "development",
    "appVersion": "1.0.0",
    "metadata": {"userId": "12345"}
  }'

# Test log endpoint
curl -X POST http://localhost:7990/api/logs \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Test log message",
    "level": "INFO",
    "timestamp": "2026-01-09T20:00:00Z",
    "file": "ViewController.swift",
    "function": "viewDidLoad()",
    "line": 25
  }'
```

## Production Considerations

For production use, consider:

1. **Authentication**: Add API key or OAuth authentication
2. **Rate Limiting**: Prevent abuse
3. **HTTPS**: Use secure connections
4. **Database**: Use a production database (PostgreSQL, MongoDB, etc.)
5. **Monitoring**: Set up alerts for critical errors
6. **Scaling**: Use a queue system for high volume
7. **Privacy**: Don't log sensitive user data

## Next Steps

- Deploy to a cloud provider (AWS, Heroku, DigitalOcean, etc.)
- Set up monitoring and alerts
- Create a dashboard to view errors and logs
- Integrate with your existing tools (Slack, PagerDuty, etc.)
