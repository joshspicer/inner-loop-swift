# Plugin System

The InnerLoop service includes a powerful plugin system that allows you to extend functionality through hooks at various lifecycle points.

## Architecture

Plugins are written in TypeScript and implement the `Plugin` abstract class. The `PluginManager` handles plugin registration and triggers hooks at appropriate times during request processing.

### Available Hooks

| Hook | When Triggered | Context |
|------|----------------|---------|
| `onInit` | When plugin is initialized | `db` |
| `onErrorReceived` | When error POST received | `errorData` |
| `onErrorStored` | After error saved to DB | `errorData`, `errorId` |
| `onBatchReceived` | When batch POST received | `batchData` |
| `onBatchStored` | After batch saved to DB | `batchData`, `batchId` |
| `onError` | When any hook throws error | `error`, plus original context |

## Configuring Plugins via Admin UI

The easiest way to configure plugins is through the **Admin UI** at `http://localhost:7990/admin`:

1. Navigate to the **Plugins** tab
2. Click **Configure Plugin**
3. Select the plugin type (e.g., GitHub)
4. Fill in the required configuration
5. Enable/disable as needed
6. Save

Plugin configurations are stored in the database and loaded automatically on startup.

## Creating a Plugin

### 1. Create Plugin File

Create a new file in `src/plugins/` (e.g., `my-plugin.ts`):

```typescript
import { Plugin, PluginContext, HookContext } from '../plugin-system';

export interface MyPluginConfig {
  apiKey: string;
  webhookUrl: string;
}

export class MyPlugin extends Plugin {
  private config: MyPluginConfig;

  constructor(config: MyPluginConfig) {
    super('my-plugin', config);
    this.config = config;
  }

  async onInit(context: PluginContext): Promise<void> {
    console.log('MyPlugin initialized');
    // Setup code here
  }

  async onErrorStored(context: PluginContext, hookContext: HookContext): Promise<void> {
    const { errorData, errorId } = hookContext;

    // Do something with the error
    await this.sendToWebhook({
      type: 'error',
      data: errorData,
      errorId
    });
  }

  async onBatchStored(context: PluginContext, hookContext: HookContext): Promise<void> {
    const { batchData, batchId } = hookContext;

    // Only process batches with user messages
    if (!batchData?.userMessage) return;

    await this.sendToWebhook({
      type: 'user-report',
      data: batchData,
      batchId
    });
  }

  private async sendToWebhook(data: any): Promise<void> {
    // Implementation here
  }
}
```

### 2. Register Plugin

Plugins can be registered programmatically in `src/server.ts` or configured via the Admin UI.

**Programmatic Registration:**

```typescript
import { MyPlugin } from './plugins/my-plugin';

// After PluginManager initialization
if (process.env.PLUGIN_MYPLUGIN_ENABLED === 'true') {
  const myPlugin = new MyPlugin({
    apiKey: process.env.PLUGIN_MYPLUGIN_API_KEY!,
    webhookUrl: process.env.PLUGIN_MYPLUGIN_WEBHOOK_URL!,
  });
  pluginManager.register(myPlugin);
}
```

### 3. Add Configuration

Add environment variables to `.env.example`:

```bash
# MyPlugin Configuration
PLUGIN_MYPLUGIN_ENABLED=false
PLUGIN_MYPLUGIN_API_KEY=your-api-key
PLUGIN_MYPLUGIN_WEBHOOK_URL=https://your-webhook.com
```

## Built-in Plugins

### GitHub Plugin

Automatically creates GitHub issues when errors occur or users report issues.

#### Configuration via Admin UI

1. Go to Admin → Plugins → Configure Plugin
2. Select "GitHub Plugin"
3. Fill in:
   - **Personal Access Token**: Your GitHub PAT with `repo` scope
   - **Repository Owner**: Username or organization
   - **Repository Name**: Target repo for issues
   - **Labels**: Comma-separated labels (e.g., `bug, innerloop`)
   - **Assignees**: Comma-separated GitHub usernames
   - **Create issue on error**: Enable to create issue for each error
   - **Create issue on batch**: Enable to create issue for user reports

#### Configuration via Environment Variables

```bash
# GitHub Plugin Configuration
PLUGIN_GITHUB_TOKEN=ghp_your_token_here
PLUGIN_GITHUB_OWNER=your-github-username
PLUGIN_GITHUB_REPO=your-repo-name
PLUGIN_GITHUB_ASSIGNEES=username1,username2
PLUGIN_GITHUB_LABELS=bug,innerloop
PLUGIN_GITHUB_CREATE_ISSUE_ON_ERROR=false
PLUGIN_GITHUB_CREATE_ISSUE_ON_BATCH=true
```

#### Features

- **Error Issues**: Creates detailed issues with stack trace and metadata
- **Batch Issues**: Creates issues from user reports with log context
- **Auto-assign**: Automatically assigns specified GitHub users
- **Labels**: Adds custom labels to issues
- **Rich Formatting**: Includes code blocks, metadata, and structured information

#### Example Issue Created

When a user reports an issue via shake-to-send:

```markdown
Title: [InnerLoop User Report] App crashed when tapping save button

## User Report

**Batch ID:** 123
**App ID:** com.example.myapp
**Environment:** production
**App Version:** 1.2.3
**Timestamp:** 2026-01-12T20:00:00Z
**Log Count:** 247

### User Description

> App crashed when tapping save button

### Error Logs

1. **[2026-01-12T19:59:58Z]** Validation failed: email is required
   - Location: `DataValidator.swift:15` in `validate`
2. **[2026-01-12T19:59:59Z]** Failed to save user data
   - Location: `UserService.swift:42` in `saveUser`

### Warning Logs

1. **[2026-01-12T19:59:50Z]** Memory usage above 80%

### Recent Activity (Info Logs)

1. [2026-01-12T19:59:45Z] User navigated to settings
2. [2026-01-12T19:59:55Z] User tapped save button

---
*This issue was automatically created by [InnerLoop](https://github.com/joshspicer/inner-loop-swift) from a user report*
```

## Advanced Plugin Patterns

### Conditional Execution

```typescript
async onBatchStored(context: PluginContext, hookContext: HookContext): Promise<void> {
  const { batchData } = hookContext;

  // Only process production errors
  if (batchData?.environment !== 'production') {
    return;
  }

  // Process the batch
}
```

### Accessing Database

```typescript
async onErrorStored(context: PluginContext, hookContext: HookContext): Promise<void> {
  const { db } = context;
  const { errorId } = hookContext;

  // Query related errors
  const stmt = db.prepare('SELECT * FROM errors WHERE id = ?');
  const error = stmt.get(errorId);

  // Do something with the data
}
```

### Error Handling

```typescript
async onBatchStored(context: PluginContext, hookContext: HookContext): Promise<void> {
  try {
    // Your logic here
    await this.processData(hookContext.batchData);
  } catch (error) {
    // Log but don't throw - prevents breaking other plugins
    console.error('Failed to process batch:', error);

    // The onError hook will automatically be called with this error
  }
}

async onError(context: PluginContext, hookContext: HookContext): Promise<void> {
  // Handle errors from other hooks
  console.error('Plugin error occurred:', hookContext.error);

  // Send notification, log to external service, etc.
}
```

### Async Operations

```typescript
async onBatchReceived(context: PluginContext, hookContext: HookContext): Promise<void> {
  // Start background task but don't block
  setImmediate(async () => {
    await this.longRunningOperation(hookContext.batchData);
  });

  // Hook returns immediately
}
```

## Plugin Development Tips

1. **Keep hooks fast**: Hooks are called synchronously during request processing. Use `setImmediate()` for long operations.

2. **Handle errors gracefully**: Always catch and log errors. Throwing errors breaks other plugins.

3. **Use TypeScript types**: Leverage the type system for better development experience.

4. **Test thoroughly**: Test your plugin with various error and batch scenarios.

5. **Document configuration**: Add clear comments to `.env.example` for your plugin's settings.

6. **Log appropriately**: Use descriptive console.log messages for debugging.

## Example: Slack Plugin

Here's a complete example of a Slack notification plugin:

```typescript
import { Plugin, PluginContext, HookContext } from '../plugin-system';
import * as https from 'https';

export interface SlackPluginConfig {
  webhookUrl: string;
  channel?: string;
  username?: string;
}

export class SlackPlugin extends Plugin {
  private config: SlackPluginConfig;

  constructor(config: SlackPluginConfig) {
    super('slack', config);
    this.config = config;
  }

  async onBatchStored(context: PluginContext, hookContext: HookContext): Promise<void> {
    const { batchData, batchId } = hookContext;

    if (!batchData?.userMessage) {
      return; // Only notify for user reports
    }

    // Count error logs
    const errorCount = (batchData.logs || []).filter(
      (log: any) => log.level === 'ERROR'
    ).length;

    const message = {
      channel: this.config.channel,
      username: this.config.username || 'InnerLoop',
      text: `🔔 New user report: ${batchData.userMessage}`,
      attachments: [
        {
          color: errorCount > 0 ? 'danger' : 'warning',
          fields: [
            {
              title: 'Environment',
              value: batchData.environment,
              short: true,
            },
            {
              title: 'App Version',
              value: batchData.appVersion || 'Unknown',
              short: true,
            },
            {
              title: 'Error Logs',
              value: errorCount.toString(),
              short: true,
            },
            {
              title: 'Batch ID',
              value: batchId?.toString() || 'N/A',
              short: true,
            },
          ],
        },
      ],
    };

    await this.sendToSlack(message);
  }

  private async sendToSlack(message: any): Promise<void> {
    return new Promise((resolve, reject) => {
      const data = JSON.stringify(message);
      const url = new URL(this.config.webhookUrl);

      const options = {
        hostname: url.hostname,
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': data.length,
        },
      };

      const req = https.request(options, (res) => {
        res.on('data', () => {});
        res.on('end', () => resolve());
      });

      req.on('error', reject);
      req.write(data);
      req.end();
    });
  }
}
```

## Testing Plugins

Create a test file to verify your plugin:

```typescript
// tests/plugins/my-plugin.test.ts
import { MyPlugin } from '../../src/plugins/my-plugin';

describe('MyPlugin', () => {
  it('should initialize correctly', async () => {
    const plugin = new MyPlugin({
      apiKey: 'test-key',
      webhookUrl: 'https://test.com',
    });

    const context = { db: mockDb };
    await plugin.onInit(context);

    // Assert initialization
  });

  it('should handle errors gracefully', async () => {
    // Test error scenarios
  });
});
```

## Contributing Plugins

To contribute a new plugin:

1. Create the plugin in `src/plugins/`
2. Add tests
3. Update this documentation
4. Submit a pull request

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.
