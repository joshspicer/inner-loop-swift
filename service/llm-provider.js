const https = require('https');

class LLMProvider {
    constructor() {
        this.provider = process.env.LLM_PROVIDER || 'openai';
        this.openaiKey = process.env.OPENAI_API_KEY;
        this.openaiModel = process.env.OPENAI_MODEL || 'gpt-4';
        this.anthropicKey = process.env.ANTHROPIC_API_KEY;
        this.anthropicModel = process.env.ANTHROPIC_MODEL || 'claude-3-5-sonnet-20241022';
    }

    async analyzeError(errorData) {
        const prompt = this.buildErrorPrompt(errorData);
        return await this.callLLM(prompt);
    }

    async analyzeBatch(batchData) {
        const prompt = this.buildBatchPrompt(batchData);
        return await this.callLLM(prompt);
    }

    buildErrorPrompt(errorData) {
        return `You are an expert iOS developer helping debug issues. Analyze this error and provide actionable insights.

Error Information:
- Message: ${errorData.message}
- Environment: ${errorData.environment}
- App Version: ${errorData.appVersion || 'Unknown'}
- Timestamp: ${errorData.timestamp}

Stack Trace:
${errorData.stackTrace || 'No stack trace available'}

Metadata:
${JSON.stringify(errorData.metadata || {}, null, 2)}

Please provide:
1. Root cause analysis - what likely caused this error?
2. Immediate fix suggestions - what should be changed in the code?
3. Prevention strategies - how to avoid this in the future?
4. Additional context needed - what other information would help debug this?

Keep your response concise and actionable.`;
    }

    buildBatchPrompt(batchData) {
        const errorLogs = (batchData.logs || []).filter(log => log.level === 'ERROR');
        const warningLogs = (batchData.logs || []).filter(log => log.level === 'WARNING');
        const recentLogs = (batchData.logs || []).slice(-50); // Last 50 logs for context

        let prompt = `You are an expert iOS developer helping debug issues. A user has submitted logs from their app${batchData.userMessage ? ' with a specific issue' : ''}.

`;

        if (batchData.userMessage) {
            prompt += `User's Description:
"${batchData.userMessage}"

`;
        }

        prompt += `Context:
- Environment: ${batchData.environment}
- App Version: ${batchData.appVersion || 'Unknown'}
- Total Logs: ${batchData.logs?.length || 0}
- Errors: ${errorLogs.length}
- Warnings: ${warningLogs.length}
- Timestamp: ${batchData.timestamp}

`;

        if (errorLogs.length > 0) {
            prompt += `Error Logs (${errorLogs.length}):\n`;
            errorLogs.slice(0, 10).forEach((log, idx) => {
                prompt += `${idx + 1}. [${log.timestamp}] ${log.message} (${log.file}:${log.line})\n`;
            });
            if (errorLogs.length > 10) {
                prompt += `... and ${errorLogs.length - 10} more errors\n`;
            }
            prompt += '\n';
        }

        if (warningLogs.length > 0) {
            prompt += `Warning Logs (${warningLogs.length}):\n`;
            warningLogs.slice(0, 5).forEach((log, idx) => {
                prompt += `${idx + 1}. [${log.timestamp}] ${log.message} (${log.file}:${log.line})\n`;
            });
            if (warningLogs.length > 5) {
                prompt += `... and ${warningLogs.length - 5} more warnings\n`;
            }
            prompt += '\n';
        }

        prompt += `Recent Log Context (last 50 logs):\n`;
        recentLogs.forEach(log => {
            prompt += `[${log.level}] ${log.message}\n`;
        });

        prompt += `\nMetadata:
${JSON.stringify(batchData.metadata || {}, null, 2)}

Please provide:
1. Issue identification - what is the main problem based on the logs and user description?
2. Root cause - what likely caused this issue?
3. Step-by-step fix - specific code changes or actions to resolve this
4. Testing recommendations - how to verify the fix works
5. Related issues - any other problems you noticed in the logs

Keep your response clear, actionable, and developer-friendly.`;

        return prompt;
    }

    async callLLM(prompt) {
        if (this.provider === 'openai') {
            return await this.callOpenAI(prompt);
        } else if (this.provider === 'anthropic') {
            return await this.callAnthropic(prompt);
        } else {
            throw new Error(`Unknown LLM provider: ${this.provider}`);
        }
    }

    async callOpenAI(prompt) {
        if (!this.openaiKey) {
            throw new Error('OpenAI API key not configured');
        }

        const data = JSON.stringify({
            model: this.openaiModel,
            messages: [
                {
                    role: 'system',
                    content: 'You are an expert iOS developer and debugging assistant. Provide clear, actionable advice.'
                },
                {
                    role: 'user',
                    content: prompt
                }
            ],
            temperature: 0.7,
            max_tokens: 2000
        });

        const options = {
            hostname: 'api.openai.com',
            port: 443,
            path: '/v1/chat/completions',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.openaiKey}`,
                'Content-Length': data.length
            }
        };

        return new Promise((resolve, reject) => {
            const req = https.request(options, (res) => {
                let body = '';

                res.on('data', (chunk) => {
                    body += chunk;
                });

                res.on('end', () => {
                    try {
                        const response = JSON.parse(body);
                        if (response.error) {
                            reject(new Error(response.error.message));
                        } else {
                            resolve(response.choices[0].message.content);
                        }
                    } catch (error) {
                        reject(new Error('Failed to parse OpenAI response: ' + error.message));
                    }
                });
            });

            req.on('error', (error) => {
                reject(error);
            });

            req.write(data);
            req.end();
        });
    }

    async callAnthropic(prompt) {
        if (!this.anthropicKey) {
            throw new Error('Anthropic API key not configured');
        }

        const data = JSON.stringify({
            model: this.anthropicModel,
            max_tokens: 2000,
            messages: [
                {
                    role: 'user',
                    content: prompt
                }
            ]
        });

        const options = {
            hostname: 'api.anthropic.com',
            port: 443,
            path: '/v1/messages',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': this.anthropicKey,
                'anthropic-version': '2023-06-01',
                'Content-Length': data.length
            }
        };

        return new Promise((resolve, reject) => {
            const req = https.request(options, (res) => {
                let body = '';

                res.on('data', (chunk) => {
                    body += chunk;
                });

                res.on('end', () => {
                    try {
                        const response = JSON.parse(body);
                        if (response.error) {
                            reject(new Error(response.error.message));
                        } else {
                            resolve(response.content[0].text);
                        }
                    } catch (error) {
                        reject(new Error('Failed to parse Anthropic response: ' + error.message));
                    }
                });
            });

            req.on('error', (error) => {
                reject(error);
            });

            req.write(data);
            req.end();
        });
    }
}

module.exports = LLMProvider;
