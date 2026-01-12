import express, { Request, Response } from 'express';
import Database from 'better-sqlite3';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { LLMProvider } from './llm-provider';
import { PluginManager } from './plugin-system';
import { GitHubPlugin } from './plugins/github-plugin';
import { ErrorData, BatchData } from './plugin-system';
import { AuthManager, AuthenticatedRequest } from './auth';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json({ limit: '10mb' }));

// Serve static files from public directory
app.use(express.static(path.join(__dirname, '../public')));

// Initialize database
const dbPath = process.env.DATABASE_PATH || './data/innerloop.db';
const dbDir = path.dirname(dbPath);
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const db = new Database(dbPath);

// Create tables
db.exec(`
    CREATE TABLE IF NOT EXISTS errors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_id TEXT NOT NULL,
        message TEXT NOT NULL,
        stack_trace TEXT,
        timestamp TEXT NOT NULL,
        environment TEXT,
        app_version TEXT,
        metadata TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS log_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_id TEXT NOT NULL,
        user_message TEXT,
        timestamp TEXT NOT NULL,
        environment TEXT,
        app_version TEXT,
        metadata TEXT,
        log_count INTEGER,
        analyzed BOOLEAN DEFAULT FALSE,
        analysis TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS batch_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        level TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        file TEXT,
        function TEXT,
        line INTEGER,
        FOREIGN KEY (batch_id) REFERENCES log_batches(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_errors_timestamp ON errors(timestamp);
    CREATE INDEX IF NOT EXISTS idx_errors_app_id ON errors(app_id);
    CREATE INDEX IF NOT EXISTS idx_batches_timestamp ON log_batches(timestamp);
    CREATE INDEX IF NOT EXISTS idx_batches_app_id ON log_batches(app_id);
    CREATE INDEX IF NOT EXISTS idx_batch_logs_batch_id ON batch_logs(batch_id);
`);

console.log('Database initialized at:', dbPath);

// Auth Manager
const authManager = new AuthManager(db);

// LLM Integration
const llm = new LLMProvider();

// Plugin System
const pluginManager = new PluginManager({ db, llm });

// Register plugins
if (process.env.GITHUB_TOKEN && process.env.GITHUB_OWNER && process.env.GITHUB_REPO) {
  const githubPlugin = new GitHubPlugin({
    token: process.env.GITHUB_TOKEN,
    owner: process.env.GITHUB_OWNER,
    repo: process.env.GITHUB_REPO,
    assignees: process.env.GITHUB_ASSIGNEES?.split(',').map(a => a.trim()),
    labels: process.env.GITHUB_LABELS?.split(',').map(l => l.trim()),
    createIssueOnError: process.env.GITHUB_CREATE_ISSUE_ON_ERROR === 'true',
    createIssueOnBatch: process.env.GITHUB_CREATE_ISSUE_ON_BATCH === 'true',
  });
  pluginManager.register(githubPlugin);
}

// Initialize plugins
pluginManager.init().catch(err => {
  console.error('Failed to initialize plugins:', err);
});

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Web Admin Authentication Middleware
const adminPassword = process.env.ADMIN_PASSWORD || 'admin';

function authenticateAdmin(req: Request, res: Response, next: Function) {
  const authHeader = req.header('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const password = authHeader.substring(7);
  if (password !== adminPassword) {
    res.status(401).json({ error: 'Invalid password' });
    return;
  }

  next();
}

// Admin API endpoints
app.post('/admin/login', (req: Request, res: Response) => {
  const { password } = req.body;
  if (password === adminPassword) {
    res.json({ success: true });
  } else {
    res.status(401).json({ error: 'Invalid password' });
  }
});

app.get('/admin/clients', authenticateAdmin, (req: Request, res: Response) => {
  const clients = authManager.listClients();
  res.json(clients);
});

app.post('/admin/clients', authenticateAdmin, (req: Request, res: Response) => {
  const { appId, appName, sharedSecret } = req.body;

  if (!appId || !appName || !sharedSecret) {
    res.status(400).json({ error: 'Missing required fields' });
    return;
  }

  try {
    const client = authManager.createClient(appId, appName, sharedSecret);
    res.json(client);
  } catch (error) {
    res.status(400).json({ error: 'Client already exists or invalid data' });
  }
});

app.put('/admin/clients/:appId', authenticateAdmin, (req: Request, res: Response) => {
  const { appId } = req.params;
  const updates = req.body;

  try {
    authManager.updateClient(appId, updates);
    res.json({ success: true });
  } catch (error) {
    res.status(400).json({ error: 'Failed to update client' });
  }
});

app.delete('/admin/clients/:appId', authenticateAdmin, (req: Request, res: Response) => {
  const { appId } = req.params;

  try {
    authManager.deleteClient(appId);
    res.json({ success: true });
  } catch (error) {
    res.status(400).json({ error: 'Failed to delete client' });
  }
});

// Receive error reports (authenticated)
app.post('/api/errors', authManager.authenticateClient.bind(authManager), async (req: AuthenticatedRequest, res: Response) => {
  const errorData: ErrorData = {
    ...req.body,
    appId: req.appId!
  };

  console.log('=== Error Report Received ===');
  console.log('App ID:', errorData.appId);
  console.log('Timestamp:', errorData.timestamp);
  console.log('Environment:', errorData.environment);
  console.log('App Version:', errorData.appVersion);
  console.log('Message:', errorData.message);
  console.log('=============================\n');

  // Trigger onErrorReceived hook
  await pluginManager.trigger('onErrorReceived', { errorData });

  try {
    // Store error in database
    const stmt = db.prepare(`
            INSERT INTO errors (app_id, message, stack_trace, timestamp, environment, app_version, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

    const result = stmt.run(
      errorData.appId,
      errorData.message,
      errorData.stackTrace,
      errorData.timestamp,
      errorData.environment,
      errorData.appVersion,
      JSON.stringify(errorData.metadata || {})
    );

    const errorId = Number(result.lastInsertRowid);

    // Trigger onErrorStored hook
    await pluginManager.trigger('onErrorStored', { errorData, errorId });

    // Analyze error with LLM if enabled
    if (process.env.ENABLE_LLM === 'true' && process.env.AUTO_ANALYZE_ERRORS === 'true') {
      // Run analysis in background
      setImmediate(async () => {
        try {
          const analysis = await llm.analyzeError(errorData);
          console.log('\n=== LLM Analysis ===');
          console.log(analysis);
          console.log('===================\n');

          // Trigger onErrorAnalyzed hook
          await pluginManager.trigger('onErrorAnalyzed', { errorData, errorId, analysis });
        } catch (err) {
          console.error('Error analyzing with LLM:', (err as Error).message);
        }
      });
    }

    res.status(200).json({
      status: 'received',
      id: errorId,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error storing error report:', error);
    res.status(500).json({ error: 'Failed to store error report' });
  }
});

// Receive log batches (authenticated)
app.post('/api/batch', authManager.authenticateClient.bind(authManager), async (req: AuthenticatedRequest, res: Response) => {
  const batchData: BatchData = {
    ...req.body,
    appId: req.appId!
  };

  console.log('=== Log Batch Received ===');
  console.log('App ID:', batchData.appId);
  console.log('Timestamp:', batchData.timestamp);
  console.log('Environment:', batchData.environment);
  console.log('Log Count:', batchData.logs?.length || 0);
  console.log('User Message:', batchData.userMessage || 'None');
  console.log('==========================\n');

  // Trigger onBatchReceived hook
  await pluginManager.trigger('onBatchReceived', { batchData });

  try {
    // Store batch in database
    const batchStmt = db.prepare(`
            INSERT INTO log_batches (app_id, user_message, timestamp, environment, app_version, metadata, log_count)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

    const batchResult = batchStmt.run(
      batchData.appId,
      batchData.userMessage || null,
      batchData.timestamp,
      batchData.environment,
      batchData.appVersion,
      JSON.stringify(batchData.metadata || {}),
      batchData.logs?.length || 0
    );

    const batchId = Number(batchResult.lastInsertRowid);

    // Store individual logs
    if (batchData.logs && batchData.logs.length > 0) {
      const logStmt = db.prepare(`
                INSERT INTO batch_logs (batch_id, message, level, timestamp, file, function, line)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `);

      const insertMany = db.transaction((logs: any[]) => {
        for (const log of logs) {
          logStmt.run(batchId, log.message, log.level, log.timestamp, log.file, log.function, log.line);
        }
      });

      insertMany(batchData.logs);
    }

    // Trigger onBatchStored hook
    await pluginManager.trigger('onBatchStored', { batchData, batchId });

    // Analyze with LLM if there's a user message (indicates something important)
    if (process.env.ENABLE_LLM === 'true' && batchData.userMessage) {
      // Run analysis in background
      setImmediate(async () => {
        try {
          const analysis = await llm.analyzeBatch(batchData);
          console.log('\n=== LLM Analysis ===');
          console.log(analysis);
          console.log('===================\n');

          // Store analysis
          const updateStmt = db.prepare(`
                        UPDATE log_batches
                        SET analyzed = TRUE, analysis = ?
                        WHERE id = ?
                    `);
          updateStmt.run(analysis, batchId);

          // Trigger onBatchAnalyzed hook
          await pluginManager.trigger('onBatchAnalyzed', { batchData, batchId, analysis });
        } catch (err) {
          console.error('Error analyzing batch with LLM:', (err as Error).message);
        }
      });
    }

    res.status(200).json({
      status: 'received',
      batchId: batchId,
      logCount: batchData.logs?.length || 0,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error storing log batch:', error);
    res.status(500).json({ error: 'Failed to store log batch' });
  }
});

// Query errors
app.get('/api/errors', (req: Request, res: Response) => {
  try {
    const limit = parseInt(req.query.limit as string) || 50;
    const appId = req.query.appId as string;

    let query = 'SELECT * FROM errors';
    const params: any[] = [];

    if (appId) {
      query += ' WHERE app_id = ?';
      params.push(appId);
    }

    query += ' ORDER BY created_at DESC LIMIT ?';
    params.push(limit);

    const stmt = db.prepare(query);
    const errors = stmt.all(...params);

    res.json({
      count: errors.length,
      errors: errors.map((e: any) => ({
        ...e,
        metadata: JSON.parse(e.metadata || '{}'),
      })),
    });
  } catch (error) {
    console.error('Error querying errors:', error);
    res.status(500).json({ error: 'Failed to query errors' });
  }
});

// Query log batches
app.get('/api/batches', (req: Request, res: Response) => {
  try {
    const limit = parseInt(req.query.limit as string) || 50;
    const appId = req.query.appId as string;

    let query = 'SELECT * FROM log_batches';
    const params: any[] = [];

    if (appId) {
      query += ' WHERE app_id = ?';
      params.push(appId);
    }

    query += ' ORDER BY created_at DESC LIMIT ?';
    params.push(limit);

    const stmt = db.prepare(query);
    const batches = stmt.all(...params);

    res.json({
      count: batches.length,
      batches: batches.map((b: any) => ({
        ...b,
        metadata: JSON.parse(b.metadata || '{}'),
      })),
    });
  } catch (error) {
    console.error('Error querying batches:', error);
    res.status(500).json({ error: 'Failed to query batches' });
  }
});

// Get batch details with logs
app.get('/api/batches/:id', (req: Request, res: Response) => {
  try {
    const batchId = parseInt(req.params.id);

    const batchStmt = db.prepare('SELECT * FROM log_batches WHERE id = ?');
    const batch: any = batchStmt.get(batchId);

    if (!batch) {
      return res.status(404).json({ error: 'Batch not found' });
    }

    const logsStmt = db.prepare('SELECT * FROM batch_logs WHERE batch_id = ? ORDER BY timestamp ASC');
    const logs = logsStmt.all(batchId);

    res.json({
      ...batch,
      metadata: JSON.parse(batch.metadata || '{}'),
      logs: logs,
    });
  } catch (error) {
    console.error('Error querying batch details:', error);
    res.status(500).json({ error: 'Failed to query batch details' });
  }
});

// Trigger LLM analysis for a batch
app.post('/api/batches/:id/analyze', async (req: Request, res: Response) => {
  try {
    const batchId = parseInt(req.params.id);

    const batchStmt = db.prepare('SELECT * FROM log_batches WHERE id = ?');
    const batch: any = batchStmt.get(batchId);

    if (!batch) {
      return res.status(404).json({ error: 'Batch not found' });
    }

    const logsStmt = db.prepare('SELECT * FROM batch_logs WHERE batch_id = ? ORDER BY timestamp ASC');
    const logs = logsStmt.all(batchId);

    const batchData: BatchData = {
      appId: batch.app_id,
      userMessage: batch.user_message,
      timestamp: batch.timestamp,
      environment: batch.environment,
      appVersion: batch.app_version,
      metadata: JSON.parse(batch.metadata || '{}'),
      logs: logs as any[],
    };

    const analysis = await llm.analyzeBatch(batchData);

    // Store analysis
    const updateStmt = db.prepare(`
            UPDATE log_batches
            SET analyzed = TRUE, analysis = ?
            WHERE id = ?
        `);
    updateStmt.run(analysis, batchId);

    // Trigger onBatchAnalyzed hook
    await pluginManager.trigger('onBatchAnalyzed', { batchData, batchId, analysis });

    res.json({
      status: 'analyzed',
      batchId: batchId,
      analysis: analysis,
    });
  } catch (error) {
    console.error('Error analyzing batch:', error);
    res.status(500).json({ error: 'Failed to analyze batch: ' + (error as Error).message });
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  db.close();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server');
  db.close();
  process.exit(0);
});

// Start server
app.listen(PORT, () => {
  console.log(`InnerLoop service listening on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`LLM Provider: ${process.env.LLM_PROVIDER || 'openai'}`);
  console.log(`LLM Enabled: ${process.env.ENABLE_LLM || 'false'}`);
  console.log(`Admin Password: ${adminPassword === 'admin' ? 'DEFAULT (change this!)' : 'configured'}`);
  console.log('\nAPI endpoints:');
  console.log(`  POST   http://localhost:${PORT}/api/errors`);
  console.log(`  POST   http://localhost:${PORT}/api/batch`);
  console.log(`  GET    http://localhost:${PORT}/api/errors`);
  console.log(`  GET    http://localhost:${PORT}/api/batches`);
  console.log(`  GET    http://localhost:${PORT}/api/batches/:id`);
  console.log(`  POST   http://localhost:${PORT}/api/batches/:id/analyze`);
  console.log(`  GET    http://localhost:${PORT}/health`);
  console.log('\nAdmin endpoints:');
  console.log(`  POST   http://localhost:${PORT}/admin/login`);
  console.log(`  GET    http://localhost:${PORT}/admin/clients`);
  console.log(`  POST   http://localhost:${PORT}/admin/clients`);
  console.log(`  PUT    http://localhost:${PORT}/admin/clients/:appId`);
  console.log(`  DELETE http://localhost:${PORT}/admin/clients/:appId`);
  console.log(`\nWeb Admin: http://localhost:${PORT}/`);
});
