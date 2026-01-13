import { Request, Response, NextFunction } from 'express';
import Database from 'better-sqlite3';

export interface AuthenticatedRequest extends Request {
  appId?: string;
}

export class AuthManager {
  private db: Database.Database;

  constructor(db: Database.Database) {
    this.db = db;
    this.initDatabase();
  }

  private initDatabase(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_id TEXT UNIQUE NOT NULL,
        app_name TEXT NOT NULL,
        shared_secret TEXT NOT NULL,
        enabled BOOLEAN DEFAULT TRUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_clients_app_id ON clients(app_id);
    `);
  }

  authenticateClient(req: Request, res: Response, next: NextFunction): void {
    const appId = req.header('X-App-Id');
    const sharedSecret = req.header('X-Shared-Secret');

    if (!appId || !sharedSecret) {
      res.status(401).json({ error: 'Missing authentication credentials' });
      return;
    }

    const stmt = this.db.prepare('SELECT * FROM clients WHERE app_id = ? AND shared_secret = ? AND enabled = TRUE');
    const client = stmt.get(appId, sharedSecret);

    if (!client) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    (req as AuthenticatedRequest).appId = appId;
    next();
  }

  getClient(appId: string): any {
    const stmt = this.db.prepare('SELECT * FROM clients WHERE app_id = ?');
    return stmt.get(appId);
  }

  createClient(appId: string, appName: string, sharedSecret: string): any {
    const stmt = this.db.prepare(`
      INSERT INTO clients (app_id, app_name, shared_secret)
      VALUES (?, ?, ?)
    `);
    const result = stmt.run(appId, appName, sharedSecret);
    return { id: result.lastInsertRowid, appId, appName };
  }

  updateClient(appId: string, updates: { appName?: string; sharedSecret?: string; enabled?: boolean }): void {
    const fields: string[] = [];
    const values: any[] = [];

    if (updates.appName !== undefined) {
      fields.push('app_name = ?');
      values.push(updates.appName);
    }
    if (updates.sharedSecret !== undefined) {
      fields.push('shared_secret = ?');
      values.push(updates.sharedSecret);
    }
    if (updates.enabled !== undefined) {
      fields.push('enabled = ?');
      values.push(updates.enabled ? 1 : 0);
    }

    if (fields.length === 0) return;

    fields.push('updated_at = CURRENT_TIMESTAMP');
    values.push(appId);

    const sql = `UPDATE clients SET ${fields.join(', ')} WHERE app_id = ?`;
    this.db.prepare(sql).run(...values);
  }

  deleteClient(appId: string): void {
    this.db.prepare('DELETE FROM clients WHERE app_id = ?').run(appId);
  }

  listClients(): any[] {
    return this.db.prepare('SELECT * FROM clients ORDER BY created_at DESC').all();
  }
}
