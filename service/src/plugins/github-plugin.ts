import { Plugin, PluginContext, HookContext, HooksConfig } from '../plugin-system';
import { Octokit } from '@octokit/rest';

export interface GitHubPluginConfig {
  token: string;
  owner: string;
  repo: string;
  assignees?: string[];
  labels?: string[];
  requireUserMessage?: boolean; // Only create batch issues for user reports
  hooks?: HooksConfig; // Which hooks are enabled
}

export class GitHubPlugin extends Plugin {
  private octokit: Octokit | null = null;
  private githubConfig: GitHubPluginConfig;

  constructor(config: GitHubPluginConfig) {
    super('github', config);
    this.githubConfig = config;
  }

  async onInit(context: PluginContext): Promise<void> {
    if (!this.githubConfig.token) {
      console.warn('GitHub plugin: No token provided, plugin will be disabled');
      return;
    }

    this.octokit = new Octokit({
      auth: this.githubConfig.token,
    });

    console.log(`GitHub plugin initialized for ${this.githubConfig.owner}/${this.githubConfig.repo}`);
  }

  async onErrorStored(context: PluginContext, hookContext: HookContext): Promise<void> {
    if (!this.octokit) {
      console.warn('GitHub plugin: Octokit not initialized, skipping');
      return;
    }

    const { errorData, errorId } = hookContext;
    if (!errorData) return;

    try {
      const title = `[InnerLoop Error] ${errorData.message.substring(0, 100)}`;
      const body = this.formatErrorIssue(errorData, errorId);

      const issue = await this.octokit.issues.create({
        owner: this.githubConfig.owner,
        repo: this.githubConfig.repo,
        title,
        body,
        labels: this.githubConfig.labels || ['bug', 'innerloop'],
        assignees: this.githubConfig.assignees || [],
      });

      console.log(`GitHub issue created: ${issue.data.html_url}`);
    } catch (error) {
      console.error('Failed to create GitHub issue for error:', error);
    }
  }

  async onBatchStored(context: PluginContext, hookContext: HookContext): Promise<void> {
    if (!this.octokit) {
      console.warn('GitHub plugin: Octokit not initialized, skipping');
      return;
    }

    const { batchData, batchId } = hookContext;
    if (!batchData) return;

    // If requireUserMessage is true (default), only create issues for batches with user messages
    if (this.githubConfig.requireUserMessage !== false && !batchData.userMessage) {
      console.log('GitHub plugin: Skipping batch without user message (requireUserMessage=true)');
      return;
    }

    try {
      const messagePreview = batchData.userMessage?.substring(0, 100) || 'Log batch submitted';
      const title = `[InnerLoop User Report] ${messagePreview}`;
      const body = this.formatBatchIssue(batchData, batchId);

      const issue = await this.octokit.issues.create({
        owner: this.githubConfig.owner,
        repo: this.githubConfig.repo,
        title,
        body,
        labels: this.githubConfig.labels || ['user-report', 'innerloop'],
        assignees: this.githubConfig.assignees || [],
      });

      console.log(`GitHub issue created: ${issue.data.html_url}`);
    } catch (error) {
      console.error('Failed to create GitHub issue for batch:', error);
    }
  }

  private formatErrorIssue(errorData: any, errorId?: number): string {
    let body = '## Error Report\n\n';

    body += `**Error ID:** ${errorId || 'N/A'}\n`;
    body += `**App ID:** ${errorData.appId}\n`;
    body += `**Environment:** ${errorData.environment}\n`;
    body += `**App Version:** ${errorData.appVersion || 'Unknown'}\n`;
    body += `**Timestamp:** ${errorData.timestamp}\n\n`;

    body += '### Error Message\n\n';
    body += '```\n';
    body += errorData.message;
    body += '\n```\n\n';

    if (errorData.stackTrace) {
      body += '### Stack Trace\n\n';
      body += '```\n';
      body += errorData.stackTrace;
      body += '\n```\n\n';
    }

    if (errorData.metadata && Object.keys(errorData.metadata).length > 0) {
      body += '### Metadata\n\n';
      body += '```json\n';
      body += JSON.stringify(errorData.metadata, null, 2);
      body += '\n```\n\n';
    }

    body += '---\n';
    body += '*This issue was automatically created by [InnerLoop](https://github.com/joshspicer/inner-loop-swift)*\n';

    return body;
  }

  private formatBatchIssue(batchData: any, batchId?: number): string {
    let body = '## User Report\n\n';

    body += `**Batch ID:** ${batchId || 'N/A'}\n`;
    body += `**App ID:** ${batchData.appId}\n`;
    body += `**Environment:** ${batchData.environment}\n`;
    body += `**App Version:** ${batchData.appVersion || 'Unknown'}\n`;
    body += `**Timestamp:** ${batchData.timestamp}\n`;
    body += `**Log Count:** ${batchData.logs?.length || 0}\n\n`;

    if (batchData.userMessage) {
      body += '### User Description\n\n';
      body += '> ' + batchData.userMessage + '\n\n';
    }

    // Show error logs
    const errorLogs = (batchData.logs || []).filter((log: any) => log.level === 'ERROR');
    if (errorLogs.length > 0) {
      body += '### Error Logs\n\n';
      errorLogs.slice(0, 10).forEach((log: any, idx: number) => {
        body += `${idx + 1}. **[${log.timestamp}]** ${log.message}\n`;
        if (log.file && log.line) {
          body += `   - Location: \`${log.file}:${log.line}\``;
          if (log.function) body += ` in \`${log.function}\``;
          body += '\n';
        }
      });
      if (errorLogs.length > 10) {
        body += `\n*...and ${errorLogs.length - 10} more error logs*\n`;
      }
      body += '\n';
    }

    // Show warning logs
    const warningLogs = (batchData.logs || []).filter((log: any) => log.level === 'WARNING');
    if (warningLogs.length > 0) {
      body += '### Warning Logs\n\n';
      warningLogs.slice(0, 5).forEach((log: any, idx: number) => {
        body += `${idx + 1}. **[${log.timestamp}]** ${log.message}\n`;
      });
      if (warningLogs.length > 5) {
        body += `\n*...and ${warningLogs.length - 5} more warnings*\n`;
      }
      body += '\n';
    }

    // Show recent info logs for context
    const infoLogs = (batchData.logs || []).filter((log: any) => log.level === 'INFO').slice(-10);
    if (infoLogs.length > 0) {
      body += '### Recent Activity (Info Logs)\n\n';
      infoLogs.forEach((log: any, idx: number) => {
        body += `${idx + 1}. [${log.timestamp}] ${log.message}\n`;
      });
      body += '\n';
    }

    if (batchData.metadata && Object.keys(batchData.metadata).length > 0) {
      body += '### Metadata\n\n';
      body += '```json\n';
      body += JSON.stringify(batchData.metadata, null, 2);
      body += '\n```\n\n';
    }

    body += '---\n';
    body += '*This issue was automatically created by [InnerLoop](https://github.com/joshspicer/inner-loop-swift) from a user report*\n';

    return body;
  }
}
