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

export interface PluginConfig {
  name: string;
  enabled: boolean;
  config: Record<string, any>;
}

export interface HooksConfig {
  onInit?: boolean;
  onErrorReceived?: boolean;
  onErrorStored?: boolean;
  onBatchReceived?: boolean;
  onBatchStored?: boolean;
  onError?: boolean;
}

export interface PluginContext {
  db: any;
}

export interface HookContext {
  errorData?: ErrorData;
  errorId?: number;
  batchData?: BatchData;
  batchId?: number;
  error?: Error;
}

export abstract class Plugin {
  name: string;
  config: Record<string, any>;

  constructor(name: string, config: Record<string, any> = {}) {
    this.name = name;
    this.config = config;
  }

  // Check if a hook is enabled (defaults to true if not specified)
  isHookEnabled(hookName: string): boolean {
    const hooks = this.config.hooks as HooksConfig | undefined;
    if (!hooks) return true; // Default: all hooks enabled
    const value = hooks[hookName as keyof HooksConfig];
    return value !== false; // Treat undefined as enabled
  }

  // Lifecycle hooks - override as needed
  async onInit?(context: PluginContext): Promise<void>;
  async onErrorReceived?(context: PluginContext, hookContext: HookContext): Promise<void>;
  async onErrorStored?(context: PluginContext, hookContext: HookContext): Promise<void>;
  async onBatchReceived?(context: PluginContext, hookContext: HookContext): Promise<void>;
  async onBatchStored?(context: PluginContext, hookContext: HookContext): Promise<void>;
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

  clear(): void {
    this.plugins = [];
    console.log('All plugins cleared');
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
      // Check if this hook is enabled for this plugin
      if (!plugin.isHookEnabled(String(hookName))) {
        console.log(`Plugin ${plugin.name}: hook ${String(hookName)} is disabled, skipping`);
        continue;
      }

      const hook = plugin[hookName];
      if (typeof hook === 'function') {
        try {
          await (hook as any).call(plugin, this.context, hookContext);
        } catch (error) {
          console.error(`Error in plugin ${plugin.name} hook ${String(hookName)}:`, error);
          // Trigger onError hook if available and enabled
          if (plugin.onError && hookName !== 'onError' && plugin.isHookEnabled('onError')) {
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
