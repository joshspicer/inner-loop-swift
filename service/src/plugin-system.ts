export interface ErrorData {
  appId: string;
  message: string;
  stackTrace?: string;
  timestamp: string;
  environment: string;
  appVersion?: string;
  metadata: Record<string, any>;
}

export interface LogEntry {
  message: string;
  level: string;
  timestamp: string;
  file: string;
  function: string;
  line: number;
}

export interface BatchData {
  appId: string;
  userMessage?: string;
  timestamp: string;
  environment: string;
  appVersion?: string;
  metadata: Record<string, any>;
  logs: LogEntry[];
}

export interface PluginContext {
  db: any;
  llm: any;
}

export interface HookContext {
  errorData?: ErrorData;
  errorId?: number;
  batchData?: BatchData;
  batchId?: number;
  analysis?: string;
  error?: Error;
}

export abstract class Plugin {
  name: string;
  config: Record<string, any>;

  constructor(name: string, config: Record<string, any> = {}) {
    this.name = name;
    this.config = config;
  }

  // Lifecycle hooks - override as needed
  async onInit?(context: PluginContext): Promise<void>;
  async onErrorReceived?(context: PluginContext, hookContext: HookContext): Promise<void>;
  async onErrorStored?(context: PluginContext, hookContext: HookContext): Promise<void>;
  async onErrorAnalyzed?(context: PluginContext, hookContext: HookContext): Promise<void>;
  async onBatchReceived?(context: PluginContext, hookContext: HookContext): Promise<void>;
  async onBatchStored?(context: PluginContext, hookContext: HookContext): Promise<void>;
  async onBatchAnalyzed?(context: PluginContext, hookContext: HookContext): Promise<void>;
  async onError?(context: PluginContext, hookContext: HookContext): Promise<void>;
}

export class PluginManager {
  private plugins: Plugin[] = [];
  private context: PluginContext;

  constructor(context: PluginContext) {
    this.context = context;
  }

  register(plugin: Plugin): void {
    this.plugins.push(plugin);
    console.log(`Plugin registered: ${plugin.name}`);
  }

  async init(): Promise<void> {
    for (const plugin of this.plugins) {
      if (plugin.onInit) {
        try {
          await plugin.onInit(this.context);
          console.log(`Plugin initialized: ${plugin.name}`);
        } catch (error) {
          console.error(`Error initializing plugin ${plugin.name}:`, error);
        }
      }
    }
  }

  async trigger(hookName: keyof Plugin, hookContext: HookContext): Promise<void> {
    for (const plugin of this.plugins) {
      const hook = plugin[hookName];
      if (typeof hook === 'function') {
        try {
          await (hook as any).call(plugin, this.context, hookContext);
        } catch (error) {
          console.error(`Error in plugin ${plugin.name} hook ${String(hookName)}:`, error);
          // Trigger onError hook if available
          if (plugin.onError && hookName !== 'onError') {
            try {
              await plugin.onError(this.context, { ...hookContext, error: error as Error });
            } catch (e) {
              console.error(`Error in plugin ${plugin.name} onError hook:`, e);
            }
          }
        }
      }
    }
  }
}
