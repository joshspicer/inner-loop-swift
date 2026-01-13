import express, { Request, Response } from 'express';
import Database from 'better-sqlite3';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { PluginManager, PluginConfig, ErrorData, BatchData } from './plugin-system';
import { GitHubPlugin } from './plugins/github-plugin';
import { AuthManager, AuthenticatedRequest } from './auth';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 7990;

app.use(express.json({ limit: '10mb' }));
app.use(express.static(path.join(__dirname, '../public')));

// Initialize database
const dbPath = process.env.DATABASE_PATH || './data/innerloop.db';
const dbDir = path.dirname(dbPath);
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const db = new Database(dbPath);

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

  CREATE TABLE IF NOT EXISTS plugin_configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    config TEXT DEFAULT '{}',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE INDEX IF NOT EXISTS idx_errors_app_id ON errors(app_id);
  CREATE INDEX IF NOT EXISTS idx_batches_app_id ON log_batches(app_id);
  CREATE INDEX IF NOT EXISTS idx_batch_logs_batch_id ON batch_logs(batch_id);
`);

const authManager = new AuthManager(db);
const pluginManager = new PluginManager({ db });

// Plugin helpers
function getPluginConfig(name: string): PluginConfig | null {
  const row: any = db.prepare('SELECT * FROM plugin_configs WHERE name = ?').get(name);
  if (!row) return null;
  return { name: row.name, enabled: Boolean(row.enabled), config: JSON.parse(row.config || '{}') };
}

function getAllPluginConfigs(): PluginConfig[] {
  return (db.prepare('SELECT * FROM plugin_configs ORDER BY name').all() as any[]).map((row) => ({
    name: row.name,
    enabled: Boolean(row.enabled),
    config: JSON.parse(row.config || '{}'),
  }));
}

function savePluginConfig(pluginConfig: PluginConfig): void {
  db.prepare(`
    INSERT INTO plugin_configs (name, enabled, config, updated_at)
    VALUES (?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(name) DO UPDATE SET enabled = excluded.enabled, config = excluded.config, updated_at = CURRENT_TIMESTAMP
  `).run(pluginConfig.name, pluginConfig.enabled ? 1 : 0, JSON.stringify(pluginConfig.config));
}

async function initializePlugins(): Promise<void> {
  const defaultPlugin: PluginConfig = {
    name: 'github',
    enabled: Boolean(process.env.PLUGIN_GITHUB_TOKEN && process.env.PLUGIN_GITHUB_OWNER && process.env.PLUGIN_GITHUB_REPO),
    config: {
      token: process.env.PLUGIN_GITHUB_TOKEN || '',
      owner: process.env.PLUGIN_GITHUB_OWNER || '',
      repo: process.env.PLUGIN_GITHUB_REPO || '',
      assignees: process.env.PLUGIN_GITHUB_ASSIGNEES?.split(',').map((a) => a.trim()).filter(Boolean) || [],
      labels: process.env.PLUGIN_GITHUB_LABELS?.split(',').map((l) => l.trim()).filter(Boolean) || [],
      requireUserMessage: true,
      hooks: {
        onInit: true,
        onErrorReceived: false,
        onErrorStored: process.env.PLUGIN_GITHUB_CREATE_ISSUE_ON_ERROR === 'true',
        onBatchReceived: false,
        onBatchStored: process.env.PLUGIN_GITHUB_CREATE_ISSUE_ON_BATCH !== 'false',
        onError: true,
      },
    },
  };

  if (!getPluginConfig('github')) {
    savePluginConfig(defaultPlugin);
  }
  await reloadPlugins();
}

async function reloadPlugins(): Promise<void> {
  pluginManager.clear();
  for (const cfg of getAllPluginConfigs()) {
    if (!cfg.enabled) continue;
    if (cfg.name === 'github' && cfg.config.token && cfg.config.owner && cfg.config.repo) {
      pluginManager.register(new GitHubPlugin(cfg.config as any));
    }
  }
  await pluginManager.init();
}

initializePlugins().catch(console.error);

// Health check
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Admin auth
const adminPassword = process.env.ADMIN_PASSWORD || 'admin';

function authenticateAdmin(req: Request, res: Response, next: Function) {
  const authHeader = req.header('Authorization');
  if (!authHeader?.startsWith('Bearer ') || authHeader.substring(7) !== adminPassword) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  next();
}

app.post('/admin/login', (req: Request, res: Response) => {
  const valid = req.body.password === adminPassword;
  res.status(valid ? 200 : 401).json(valid ? { success: true } : { error: 'Invalid password' });
});

// Client management
app.get('/admin/clients', authenticateAdmin, (_req: Request, res: Response) => {
  res.json(authManager.listClients());
});

app.post('/admin/clients', authenticateAdmin, (req: Request, res: Response) => {
  const { appId, appName, sharedSecret } = req.body;
  if (!appId || !appName || !sharedSecret) {
    res.status(400).json({ error: 'Missing required fields' });
    return;
  }
  try {
    res.json(authManager.createClient(appId, appName, sharedSecret));
  } catch {
    res.status(400).json({ error: 'Client already exists' });
  }
});

app.put('/admin/clients/:appId', authenticateAdmin, (req: Request, res: Response) => {
  try {
    authManager.updateClient(req.params.appId, req.body);
    res.json({ success: true });
  } catch {
    res.status(400).json({ error: 'Failed to update client' });
  }
});

app.delete('/admin/clients/:appId', authenticateAdmin, (req: Request, res: Response) => {
  try {
    authManager.deleteClient(req.params.appId);
    res.json({ success: true });
  } catch {
    res.status(400).json({ error: 'Failed to delete client' });
  }
});

// Plugin management
app.get('/admin/plugins', authenticateAdmin, (_req: Request, res: Response) => {
  res.json(getAllPluginConfigs());
});

app.post('/admin/plugins', authenticateAdmin, async (req: Request, res: Response) => {
  const { name, enabled = true, config = {} } = req.body;
  if (!name) {
    res.status(400).json({ error: 'Plugin name is required' });
    return;
  }
  savePluginConfig({ name, enabled, config });
  await reloadPlugins();
  res.json({ success: true });
});

app.put('/admin/plugins/:name', authenticateAdmin, async (req: Request, res: Response) => {
  const existing = getPluginConfig(req.params.name);
  if (!existing) {
    res.status(404).json({ error: 'Plugin not found' });
    return;
  }
  const { enabled, config } = req.body;
  savePluginConfig({
    name: req.params.name,
    enabled: enabled ?? existing.enabled,
    config: config ? { ...existing.config, ...config } : existing.config,
  });
  await reloadPlugins();
  res.json({ success: true });
});

app.delete('/admin/plugins/:name', authenticateAdmin, async (req: Request, res: Response) => {
  if (!getPluginConfig(req.params.name)) {
    res.status(404).json({ error: 'Plugin not found' });
    return;
  }
  db.prepare('DELETE FROM plugin_configs WHERE name = ?').run(req.params.name);
  await reloadPlugins();
  res.json({ success: true });
});

// Admin log viewing
app.get('/admin/errors', authenticateAdmin, (req: Request, res: Response) => {
  const limit = parseInt(req.query.limit as string) || 100;
  const offset = parseInt(req.query.offset as string) || 0;
  const appId = req.query.appId as string;

  const where = appId ? 'WHERE app_id = ?' : '';
  const params = appId ? [appId] : [];

  const total = (db.prepare(`SELECT COUNT(*) as c FROM errors ${where}`).get(...params) as any).c;
  const errors = db.prepare(`SELECT * FROM errors ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`).all(...params, limit, offset);

  res.json({
    total,
    count: errors.length,
    offset,
    limit,
    errors: (errors as any[]).map((e) => ({ ...e, metadata: JSON.parse(e.metadata || '{}') })),
  });
});

app.get('/admin/batches', authenticateAdmin, (req: Request, res: Response) => {
  const limit = parseInt(req.query.limit as string) || 100;
  const offset = parseInt(req.query.offset as string) || 0;
  const appId = req.query.appId as string;

  const where = appId ? 'WHERE app_id = ?' : '';
  const params = appId ? [appId] : [];

  const total = (db.prepare(`SELECT COUNT(*) as c FROM log_batches ${where}`).get(...params) as any).c;
  const batches = db.prepare(`SELECT * FROM log_batches ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`).all(...params, limit, offset);

  res.json({
    total,
    count: batches.length,
    offset,
    limit,
    batches: (batches as any[]).map((b) => ({ ...b, metadata: JSON.parse(b.metadata || '{}') })),
  });
});

app.get('/admin/batches/:id', authenticateAdmin, (req: Request, res: Response) => {
  const batch: any = db.prepare('SELECT * FROM log_batches WHERE id = ?').get(req.params.id);
  if (!batch) {
    res.status(404).json({ error: 'Batch not found' });
    return;
  }
  const logs = db.prepare('SELECT * FROM batch_logs WHERE batch_id = ? ORDER BY timestamp ASC').all(batch.id);
  res.json({ ...batch, metadata: JSON.parse(batch.metadata || '{}'), logs });
});

app.get('/admin/stats', authenticateAdmin, (_req: Request, res: Response) => {
  const count = (table: string) => (db.prepare(`SELECT COUNT(*) as c FROM ${table}`).get() as any).c;
  const countToday = (table: string) => (db.prepare(`SELECT COUNT(*) as c FROM ${table} WHERE date(created_at) = date('now')`).get() as any).c;

  res.json({
    totals: {
      errors: count('errors'),
      batches: count('log_batches'),
      clients: count('clients'),
      enabledPlugins: (db.prepare('SELECT COUNT(*) as c FROM plugin_configs WHERE enabled = 1').get() as any).c,
    },
    today: { errors: countToday('errors'), batches: countToday('log_batches') },
  });
});

// API endpoints (authenticated)
app.post('/api/errors', authManager.authenticateClient.bind(authManager), async (req: AuthenticatedRequest, res: Response) => {
  const errorData: ErrorData = { ...req.body, appId: req.appId! };

  await pluginManager.trigger('onErrorReceived', { errorData });

  const result = db.prepare(`
    INSERT INTO errors (app_id, message, stack_trace, timestamp, environment, app_version, metadata)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(errorData.appId, errorData.message, errorData.stackTrace, errorData.timestamp, errorData.environment, errorData.appVersion, JSON.stringify(errorData.metadata || {}));

  const errorId = Number(result.lastInsertRowid);
  await pluginManager.trigger('onErrorStored', { errorData, errorId });

  res.json({ status: 'received', id: errorId, timestamp: new Date().toISOString() });
});

app.post('/api/batch', authManager.authenticateClient.bind(authManager), async (req: AuthenticatedRequest, res: Response) => {
  const batchData: BatchData = { ...req.body, appId: req.appId! };

  await pluginManager.trigger('onBatchReceived', { batchData });

  const batchResult = db.prepare(`
    INSERT INTO log_batches (app_id, user_message, timestamp, environment, app_version, metadata, log_count)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(batchData.appId, batchData.userMessage || null, batchData.timestamp, batchData.environment, batchData.appVersion, JSON.stringify(batchData.metadata || {}), batchData.logs?.length || 0);

  const batchId = Number(batchResult.lastInsertRowid);

  if (batchData.logs?.length) {
    const logStmt = db.prepare('INSERT INTO batch_logs (batch_id, message, level, timestamp, file, function, line) VALUES (?, ?, ?, ?, ?, ?, ?)');
    const insertMany = db.transaction((logs: any[]) => {
      for (const log of logs) logStmt.run(batchId, log.message, log.level, log.timestamp, log.file, log.function, log.line);
    });
    insertMany(batchData.logs);
  }

  await pluginManager.trigger('onBatchStored', { batchData, batchId });

  res.json({ status: 'received', batchId, logCount: batchData.logs?.length || 0, timestamp: new Date().toISOString() });
});

// Graceful shutdown
process.on('SIGTERM', () => { db.close(); process.exit(0); });
process.on('SIGINT', () => { db.close(); process.exit(0); });

app.listen(PORT, () => {
  console.log(`InnerLoop service: http://localhost:${PORT}`);
  console.log(`Admin UI: http://localhost:${PORT}/admin`);
});
