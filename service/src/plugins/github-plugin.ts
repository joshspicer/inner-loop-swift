import { Plugin, PluginContext, HookContext } from '../plugin-system';
import { Octokit } from '@octokit/rest';

export interface GitHubPluginConfig {
  token: string;
  owner: string;
  repo: string;
  assignees?: string[];
  labels?: string[];
  createIssueOnError?: boolean;
  createIssueOnBatch?: boolean;
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

  async onErrorAnalyzed(context: PluginContext, hookContext: HookContext): Promise<void> {
    if (!this.githubConfig.createIssueOnError || !this.octokit) {
      return;
    }

    const { errorData, errorId, analysis } = hookContext;
    if (!errorData) return;

    try {
      const title = `[InnerLoop Error] ${errorData.message.substring(0, 100)}`;
      const body = this.formatErrorIssue(errorData, errorId, analysis);

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

  async onBatchAnalyzed(context: PluginContext, hookContext: HookContext): Promise<void> {
    if (!this.githubConfig.createIssueOnBatch || !this.octokit) {
      return;
    }

    const { batchData, batchId, analysis } = hookContext;
    if (!batchData || !batchData.userMessage) {
      // Only create issues for batches with user messages
      return;
    }

    try {
      const title = `[InnerLoop User Report] ${batchData.userMessage.substring(0, 100)}`;
      const body = this.formatBatchIssue(batchData, batchId, analysis);

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

  private formatErrorIssue(errorData: any, errorId?: number, analysis?: string): string {
    let body = '## Error Report\n\n';

    body += `**Error ID:** ${errorId || 'N/A'}\n`;
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

    if (analysis) {
      body += '### AI Analysis\n\n';
      body += analysis;
      body += '\n\n';
    }

    body += '---\n';
    body += '*This issue was automatically created by InnerLoop*\n';

    return body;
  }

  private formatBatchIssue(batchData: any, batchId?: number, analysis?: string): string {
    let body = '## User Report\n\n';

    body += `**Batch ID:** ${batchId || 'N/A'}\n`;
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
      errorLogs.slice(0, 5).forEach((log: any, idx: number) => {
        body += `${idx + 1}. **[${log.timestamp}]** ${log.message}\n`;
        body += `   - Location: \`${log.file}:${log.line}\` in \`${log.function}\`\n`;
      });
      if (errorLogs.length > 5) {
        body += `\n*...and ${errorLogs.length - 5} more error logs*\n`;
      }
      body += '\n';
    }

    // Show warning logs
    const warningLogs = (batchData.logs || []).filter((log: any) => log.level === 'WARNING');
    if (warningLogs.length > 0) {
      body += '### Warning Logs\n\n';
      warningLogs.slice(0, 3).forEach((log: any, idx: number) => {
        body += `${idx + 1}. **[${log.timestamp}]** ${log.message}\n`;
      });
      if (warningLogs.length > 3) {
        body += `\n*...and ${warningLogs.length - 3} more warnings*\n`;
      }
      body += '\n';
    }

    if (batchData.metadata && Object.keys(batchData.metadata).length > 0) {
      body += '### Metadata\n\n';
      body += '```json\n';
      body += JSON.stringify(batchData.metadata, null, 2);
      body += '\n```\n\n';
    }

    if (analysis) {
      body += '### AI Analysis\n\n';
      body += analysis;
      body += '\n\n';
    }

    body += '---\n';
    body += '*This issue was automatically created by InnerLoop from a user report*\n';

    return body;
  }
}
