// State
let authToken = null;
let clients = [];
let errors = [];
let batches = [];
let plugins = [];
let editingClientId = null;
let editingPluginId = null;
let deleteTarget = null; // { type: 'client'|'plugin', id: string }

// DOM Elements
const loginContainer = document.getElementById('login-container');
const adminContainer = document.getElementById('admin-container');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const logoutBtn = document.getElementById('logout-btn');
const statsSummary = document.getElementById('stats-summary');

// Clients
const addClientBtn = document.getElementById('add-client-btn');
const refreshClientsBtn = document.getElementById('refresh-clients-btn');
const clientsList = document.getElementById('clients-list');
const clientModal = document.getElementById('client-modal');
const clientForm = document.getElementById('client-form');
const formError = document.getElementById('form-error');
const generateSecretBtn = document.getElementById('generate-secret-btn');

// Delete Modal
const deleteModal = document.getElementById('delete-modal');
const confirmDeleteBtn = document.getElementById('confirm-delete-btn');

// Logs
const refreshLogsBtn = document.getElementById('refresh-logs-btn');
const logsFilterApp = document.getElementById('logs-filter-app');
const errorsList = document.getElementById('errors-list');
const batchesList = document.getElementById('batches-list');
const logDetailModal = document.getElementById('log-detail-modal');

// Plugins
const addPluginBtn = document.getElementById('add-plugin-btn');
const refreshPluginsBtn = document.getElementById('refresh-plugins-btn');
const pluginsList = document.getElementById('plugins-list');
const pluginModal = document.getElementById('plugin-modal');
const pluginForm = document.getElementById('plugin-form');
const pluginNameSelect = document.getElementById('plugin-name');
const pluginFormError = document.getElementById('plugin-form-error');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkAuth();
    setupEventListeners();
});

function setupEventListeners() {
    // Login
    loginForm.addEventListener('submit', handleLogin);
    logoutBtn.addEventListener('click', handleLogout);

    // Tabs
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => switchTab(e.target.dataset.tab));
    });
    document.querySelectorAll('.sub-tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => switchSubTab(e.target.dataset.subtab));
    });

    // Client management
    addClientBtn.addEventListener('click', () => openClientModal());
    refreshClientsBtn.addEventListener('click', loadClients);
    clientForm.addEventListener('submit', handleSaveClient);
    generateSecretBtn.addEventListener('click', generateSecret);
    confirmDeleteBtn.addEventListener('click', handleConfirmDelete);

    // Logs
    refreshLogsBtn.addEventListener('click', loadLogs);
    logsFilterApp.addEventListener('change', loadLogs);

    // Plugins
    addPluginBtn.addEventListener('click', () => openPluginModal());
    refreshPluginsBtn.addEventListener('click', loadPlugins);
    pluginForm.addEventListener('submit', handleSavePlugin);
    pluginNameSelect.addEventListener('change', handlePluginNameChange);

    // Modal controls
    document.querySelectorAll('.close').forEach(btn => {
        btn.addEventListener('click', closeModals);
    });
    document.querySelectorAll('.cancel-btn').forEach(btn => {
        btn.addEventListener('click', closeModals);
    });

    // Close modal on outside click
    window.addEventListener('click', (e) => {
        if (e.target.classList.contains('modal')) {
            closeModals();
        }
    });
}

// Tab Navigation
function switchTab(tab) {
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.toggle('active', content.id === `${tab}-tab`);
    });

    // Load data for tab
    if (tab === 'clients') loadClients();
    else if (tab === 'logs') loadLogs();
    else if (tab === 'plugins') loadPlugins();
}

function switchSubTab(subtab) {
    document.querySelectorAll('.sub-tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.subtab === subtab);
    });
    document.querySelectorAll('.sub-tab-content').forEach(content => {
        content.classList.toggle('active', content.id === `${subtab}-section`);
    });
}

// Authentication
function checkAuth() {
    authToken = localStorage.getItem('authToken');
    if (authToken) {
        showAdmin();
        loadClients();
        loadStats();
    } else {
        showLogin();
    }
}

async function handleLogin(e) {
    e.preventDefault();
    const password = document.getElementById('password').value;

    try {
        const response = await fetch('/admin/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ password })
        });

        if (response.ok) {
            authToken = password;
            localStorage.setItem('authToken', authToken);
            loginError.classList.remove('active');
            showAdmin();
            loadClients();
            loadStats();
        } else {
            showError(loginError, 'Invalid password');
        }
    } catch (error) {
        showError(loginError, 'Login failed: ' + error.message);
    }
}

function handleLogout() {
    authToken = null;
    localStorage.removeItem('authToken');
    showLogin();
}

function showLogin() {
    loginContainer.style.display = 'flex';
    adminContainer.style.display = 'none';
    document.getElementById('password').value = '';
}

function showAdmin() {
    loginContainer.style.display = 'none';
    adminContainer.style.display = 'block';
}

// API calls
async function apiCall(url, options = {}) {
    const headers = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`,
        ...options.headers
    };

    const response = await fetch(url, { ...options, headers });

    if (response.status === 401) {
        handleLogout();
        throw new Error('Unauthorized');
    }

    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Request failed');
    }

    return response.json();
}

// Stats
async function loadStats() {
    try {
        const stats = await apiCall('/admin/stats');
        const totals = stats.totals || {};
        statsSummary.textContent = `${totals.clients || 0} clients • ${totals.errors || 0} errors • ${totals.batches || 0} batches`;
    } catch (error) {
        statsSummary.textContent = '';
    }
}

// Clients
async function loadClients() {
    try {
        clientsList.innerHTML = '<p class="loading">Loading clients...</p>';
        const data = await apiCall('/admin/clients');
        clients = data;
        renderClients();
        updateAppFilter();
    } catch (error) {
        clientsList.innerHTML = `<p class="error-message active">Failed to load clients: ${error.message}</p>`;
    }
}

function renderClients() {
    if (clients.length === 0) {
        clientsList.innerHTML = '<div class="empty-state"><p>No clients registered yet.</p><p>Click "Add New Client" to get started.</p></div>';
        return;
    }

    clientsList.innerHTML = clients.map(client => `
        <div class="client-card" data-app-id="${client.app_id}">
            <div class="client-header">
                <div class="client-info">
                    <h3>${escapeHtml(client.app_name)}</h3>
                    <div class="app-id">${escapeHtml(client.app_id)}</div>
                </div>
                <div class="client-status">
                    <span class="status-badge ${client.enabled ? 'enabled' : 'disabled'}">
                        ${client.enabled ? 'Enabled' : 'Disabled'}
                    </span>
                </div>
            </div>
            <div class="client-details">
                <div class="detail-row">
                    <span class="detail-label">Shared Secret:</span>
                    <div class="secret-value">
                        <span class="detail-value secret-hidden" data-secret="${escapeHtml(client.shared_secret)}">••••••••••••••••</span>
                        <button class="btn-link toggle-secret" data-app-id="${client.app_id}">Show</button>
                    </div>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Created:</span>
                    <span class="detail-value">${new Date(client.created_at).toLocaleString()}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Last Updated:</span>
                    <span class="detail-value">${new Date(client.updated_at).toLocaleString()}</span>
                </div>
            </div>
            <div class="client-actions">
                <button class="btn btn-primary btn-small edit-client" data-app-id="${client.app_id}">Edit</button>
                <button class="btn btn-danger btn-small delete-client" data-app-id="${client.app_id}">Delete</button>
            </div>
        </div>
    `).join('');

    // Attach event listeners
    document.querySelectorAll('.toggle-secret').forEach(btn => {
        btn.addEventListener('click', handleToggleSecret);
    });
    document.querySelectorAll('.edit-client').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const appId = e.target.dataset.appId;
            const client = clients.find(c => c.app_id === appId);
            openClientModal(client);
        });
    });
    document.querySelectorAll('.delete-client').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const appId = e.target.dataset.appId;
            const client = clients.find(c => c.app_id === appId);
            openDeleteModal('client', client.app_id, `${client.app_name} (${client.app_id})`);
        });
    });
}

function handleToggleSecret(e) {
    const btn = e.target;
    const appId = btn.dataset.appId;
    const card = document.querySelector(`.client-card[data-app-id="${appId}"]`);
    const secretSpan = card.querySelector('.secret-hidden');
    const secret = secretSpan.dataset.secret;

    if (btn.textContent === 'Show') {
        secretSpan.textContent = secret;
        secretSpan.classList.remove('secret-hidden');
        btn.textContent = 'Hide';
    } else {
        secretSpan.textContent = '••••••••••••••••';
        secretSpan.classList.add('secret-hidden');
        btn.textContent = 'Show';
    }
}

// Client modal
function openClientModal(client = null) {
    editingClientId = client ? client.app_id : null;

    if (client) {
        document.getElementById('modal-title').textContent = 'Edit Client';
        document.getElementById('client-app-id').value = client.app_id;
        document.getElementById('client-app-id').disabled = true;
        document.getElementById('client-app-name').value = client.app_name;
        document.getElementById('client-shared-secret').value = client.shared_secret;
        document.getElementById('client-enabled').checked = client.enabled;
    } else {
        document.getElementById('modal-title').textContent = 'Add New Client';
        document.getElementById('client-app-id').disabled = false;
        clientForm.reset();
        generateSecret();
    }

    formError.classList.remove('active');
    clientModal.classList.add('active');
}

async function handleSaveClient(e) {
    e.preventDefault();

    const appId = document.getElementById('client-app-id').value.trim();
    const appName = document.getElementById('client-app-name').value.trim();
    const sharedSecret = document.getElementById('client-shared-secret').value.trim();
    const enabled = document.getElementById('client-enabled').checked;

    try {
        if (editingClientId) {
            await apiCall(`/admin/clients/${editingClientId}`, {
                method: 'PUT',
                body: JSON.stringify({ appName, sharedSecret, enabled })
            });
        } else {
            await apiCall('/admin/clients', {
                method: 'POST',
                body: JSON.stringify({ appId, appName, sharedSecret })
            });
        }

        closeModals();
        loadClients();
        loadStats();
    } catch (error) {
        showError(formError, error.message);
    }
}

// Delete modal
function openDeleteModal(type, id, displayName) {
    deleteTarget = { type, id };
    document.getElementById('delete-item-name').textContent = displayName;
    deleteModal.classList.add('active');
}

async function handleConfirmDelete() {
    if (!deleteTarget) return;

    try {
        if (deleteTarget.type === 'client') {
            await apiCall(`/admin/clients/${deleteTarget.id}`, { method: 'DELETE' });
            closeModals();
            loadClients();
        } else if (deleteTarget.type === 'plugin') {
            await apiCall(`/admin/plugins/${deleteTarget.id}`, { method: 'DELETE' });
            closeModals();
            loadPlugins();
        }
        loadStats();
    } catch (error) {
        alert('Failed to delete: ' + error.message);
    }
}

// Logs
function updateAppFilter() {
    logsFilterApp.innerHTML = '<option value="">All Apps</option>' +
        clients.map(c => `<option value="${escapeHtml(c.app_id)}">${escapeHtml(c.app_name)}</option>`).join('');
}

async function loadLogs() {
    const appId = logsFilterApp.value;
    await Promise.all([loadErrors(appId), loadBatches(appId)]);
}

async function loadErrors(appId = '') {
    try {
        errorsList.innerHTML = '<p class="loading">Loading errors...</p>';
        const url = appId ? `/admin/errors?appId=${encodeURIComponent(appId)}` : '/admin/errors';
        const data = await apiCall(url);
        errors = data.errors || [];
        renderErrors();
    } catch (error) {
        errorsList.innerHTML = `<p class="error-message active">Failed to load errors: ${error.message}</p>`;
    }
}

async function loadBatches(appId = '') {
    try {
        batchesList.innerHTML = '<p class="loading">Loading batches...</p>';
        const url = appId ? `/admin/batches?appId=${encodeURIComponent(appId)}` : '/admin/batches';
        const data = await apiCall(url);
        batches = data.batches || [];
        renderBatches();
    } catch (error) {
        batchesList.innerHTML = `<p class="error-message active">Failed to load batches: ${error.message}</p>`;
    }
}

function renderErrors() {
    if (errors.length === 0) {
        errorsList.innerHTML = '<div class="empty-state"><p>No errors recorded yet.</p></div>';
        return;
    }

    errorsList.innerHTML = `
        <table class="logs-table">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Time</th>
                    <th>App</th>
                    <th>Environment</th>
                    <th>Message</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${errors.map(err => `
                    <tr>
                        <td>${err.id}</td>
                        <td class="timestamp">${formatTimestamp(err.timestamp)}</td>
                        <td>${escapeHtml(err.app_id)}</td>
                        <td><span class="env-badge ${err.environment}">${err.environment}</span></td>
                        <td class="message-cell" title="${escapeHtml(err.message)}">${escapeHtml(truncate(err.message, 50))}</td>
                        <td><button class="btn btn-small btn-secondary view-error" data-id="${err.id}">View</button></td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;

    document.querySelectorAll('.view-error').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const error = errors.find(err => err.id == e.target.dataset.id);
            showErrorDetail(error);
        });
    });
}

function renderBatches() {
    if (batches.length === 0) {
        batchesList.innerHTML = '<div class="empty-state"><p>No log batches recorded yet.</p></div>';
        return;
    }

    batchesList.innerHTML = `
        <table class="logs-table">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Time</th>
                    <th>App</th>
                    <th>Environment</th>
                    <th>Logs</th>
                    <th>User Message</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${batches.map(batch => `
                    <tr>
                        <td>${batch.id}</td>
                        <td class="timestamp">${formatTimestamp(batch.timestamp)}</td>
                        <td>${escapeHtml(batch.app_id)}</td>
                        <td><span class="env-badge ${batch.environment}">${batch.environment}</span></td>
                        <td>${batch.log_count || 0}</td>
                        <td class="message-cell" title="${escapeHtml(batch.user_message || '')}">${batch.user_message ? '💬 ' + escapeHtml(truncate(batch.user_message, 30)) : '-'}</td>
                        <td><button class="btn btn-small btn-secondary view-batch" data-id="${batch.id}">View</button></td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;

    document.querySelectorAll('.view-batch').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const batch = batches.find(b => b.id == e.target.dataset.id);
            showBatchDetail(batch);
        });
    });
}

function showErrorDetail(error) {
    document.getElementById('log-detail-title').textContent = `Error #${error.id}`;
    document.getElementById('log-detail-content').innerHTML = `
        <div class="detail-section">
            <h4>Basic Info</h4>
            <div class="detail-grid">
                <div><strong>App ID:</strong> ${escapeHtml(error.app_id)}</div>
                <div><strong>Environment:</strong> <span class="env-badge ${error.environment}">${error.environment}</span></div>
                <div><strong>App Version:</strong> ${escapeHtml(error.app_version || 'N/A')}</div>
                <div><strong>Timestamp:</strong> ${new Date(error.timestamp).toLocaleString()}</div>
            </div>
        </div>
        <div class="detail-section">
            <h4>Error Message</h4>
            <pre class="code-block">${escapeHtml(error.message)}</pre>
        </div>
        ${error.stack_trace ? `
        <div class="detail-section">
            <h4>Stack Trace</h4>
            <pre class="code-block stack-trace">${escapeHtml(error.stack_trace)}</pre>
        </div>
        ` : ''}
        ${error.metadata ? `
        <div class="detail-section">
            <h4>Metadata</h4>
            <pre class="code-block">${JSON.stringify(JSON.parse(error.metadata), null, 2)}</pre>
        </div>
        ` : ''}
    `;
    logDetailModal.classList.add('active');
}

async function showBatchDetail(batch) {
    document.getElementById('log-detail-title').textContent = `Batch #${batch.id}`;

    // Fetch the full batch with logs
    try {
        const fullBatch = await apiCall(`/admin/batches/${batch.id}`);
        const logs = fullBatch.logs || [];

        document.getElementById('log-detail-content').innerHTML = `
            <div class="detail-section">
                <h4>Basic Info</h4>
                <div class="detail-grid">
                    <div><strong>App ID:</strong> ${escapeHtml(fullBatch.app_id)}</div>
                    <div><strong>Environment:</strong> <span class="env-badge ${fullBatch.environment}">${fullBatch.environment}</span></div>
                    <div><strong>App Version:</strong> ${escapeHtml(fullBatch.app_version || 'N/A')}</div>
                    <div><strong>Timestamp:</strong> ${new Date(fullBatch.timestamp).toLocaleString()}</div>
                    <div><strong>Log Count:</strong> ${logs.length}</div>
                </div>
            </div>
            ${fullBatch.user_message ? `
            <div class="detail-section user-message-section">
                <h4>💬 User Message</h4>
                <blockquote>${escapeHtml(fullBatch.user_message)}</blockquote>
            </div>
            ` : ''}
            <div class="detail-section">
                <h4>Logs</h4>
                <div class="logs-list">
                    ${logs.length === 0 ? '<p class="empty-state">No logs in this batch.</p>' : 
                    logs.map(log => `
                        <div class="log-entry log-${log.level.toLowerCase()}">
                            <div class="log-header">
                                <span class="log-level ${log.level.toLowerCase()}">${log.level}</span>
                                <span class="log-category">${escapeHtml(log.category)}</span>
                                <span class="log-timestamp">${formatTimestamp(log.timestamp)}</span>
                            </div>
                            <div class="log-message">${escapeHtml(log.message)}</div>
                            ${log.file ? `<div class="log-location">${escapeHtml(log.file)}:${log.line} in ${escapeHtml(log.function_name || 'unknown')}</div>` : ''}
                        </div>
                    `).join('')}
                </div>
            </div>
            ${fullBatch.metadata && Object.keys(fullBatch.metadata).length > 0 ? `
            <div class="detail-section">
                <h4>Metadata</h4>
                <pre class="code-block">${JSON.stringify(fullBatch.metadata, null, 2)}</pre>
            </div>
            ` : ''}
        `;
    } catch (error) {
        document.getElementById('log-detail-content').innerHTML = `<p class="error-message active">Failed to load batch details: ${error.message}</p>`;
    }

    logDetailModal.classList.add('active');
}

// Plugins
async function loadPlugins() {
    try {
        pluginsList.innerHTML = '<p class="loading">Loading plugins...</p>';
        const data = await apiCall('/admin/plugins');
        plugins = data;
        renderPlugins();
    } catch (error) {
        pluginsList.innerHTML = `<p class="error-message active">Failed to load plugins: ${error.message}</p>`;
    }
}

function renderPlugins() {
    if (plugins.length === 0) {
        pluginsList.innerHTML = '<div class="empty-state"><p>No plugins configured yet.</p><p>Click "Configure Plugin" to add one.</p></div>';
        return;
    }

    pluginsList.innerHTML = plugins.map(plugin => {
        const config = typeof plugin.config === 'string' ? JSON.parse(plugin.config) : plugin.config;
        return `
            <div class="plugin-card" data-plugin-name="${plugin.name}">
                <div class="plugin-header">
                    <div class="plugin-info">
                        <h3>${getPluginIcon(plugin.name)} ${escapeHtml(plugin.name)}</h3>
                        ${plugin.name === 'github' && config.owner && config.repo ? 
                            `<div class="plugin-target">${escapeHtml(config.owner)}/${escapeHtml(config.repo)}</div>` : ''}
                    </div>
                    <div class="plugin-status">
                        <span class="status-badge ${plugin.enabled ? 'enabled' : 'disabled'}">
                            ${plugin.enabled ? 'Enabled' : 'Disabled'}
                        </span>
                    </div>
                </div>
                <div class="plugin-details">
                    ${plugin.name === 'github' ? `
                        ${config.labels?.length ? `
                        <div class="detail-row">
                            <span class="detail-label">Labels:</span>
                            <span class="detail-value">${config.labels.map(l => `<span class="label-tag">${escapeHtml(l)}</span>`).join(' ')}</span>
                        </div>
                        ` : ''}
                        ${config.hooks ? `
                        <div class="detail-row">
                            <span class="detail-label">Active Hooks:</span>
                            <span class="detail-value">${Object.entries(config.hooks).filter(([k,v]) => v).map(([k]) => k).join(', ')}</span>
                        </div>
                        ` : ''}
                    ` : `
                        <pre class="code-block">${JSON.stringify(config, null, 2)}</pre>
                    `}
                </div>
                <div class="plugin-actions">
                    <button class="btn btn-primary btn-small edit-plugin" data-plugin-name="${plugin.name}">Edit</button>
                    <button class="btn btn-danger btn-small delete-plugin" data-plugin-name="${plugin.name}">Delete</button>
                </div>
            </div>
        `;
    }).join('');

    // Attach event listeners
    document.querySelectorAll('.edit-plugin').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const pluginName = e.target.dataset.pluginName;
            const plugin = plugins.find(p => p.name === pluginName);
            openPluginModal(plugin);
        });
    });
    document.querySelectorAll('.delete-plugin').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const pluginName = e.target.dataset.pluginName;
            const plugin = plugins.find(p => p.name === pluginName);
            openDeleteModal('plugin', plugin.name, `${plugin.name} plugin`);
        });
    });
}

function getPluginIcon(name) {
    const icons = {
        'github': '🔗',
        'slack': '💬',
        'webhook': '🌐'
    };
    return icons[name] || '🔌';
}

function openPluginModal(plugin = null) {
    editingPluginId = plugin ? plugin.name : null;
    pluginForm.reset();

    // Hide all plugin config sections
    document.querySelectorAll('.plugin-config-section').forEach(el => el.style.display = 'none');

    // Default hooks (all enabled by default except Received hooks)
    const defaultHooks = {
        onInit: true,
        onErrorReceived: false,
        onErrorStored: true,
        onBatchReceived: false,
        onBatchStored: true,
        onError: true
    };

    if (plugin) {
        document.getElementById('plugin-modal-title').textContent = 'Edit Plugin';
        pluginNameSelect.value = plugin.name;
        pluginNameSelect.disabled = true;
        document.getElementById('plugin-enabled').checked = plugin.enabled;

        const config = typeof plugin.config === 'string' ? JSON.parse(plugin.config) : plugin.config;
        const hooks = config.hooks || defaultHooks;

        // Show hooks config
        document.getElementById('hooks-config').style.display = 'block';
        document.getElementById('hook-onInit').checked = hooks.onInit !== false;
        document.getElementById('hook-onErrorReceived').checked = hooks.onErrorReceived === true;
        document.getElementById('hook-onErrorStored').checked = hooks.onErrorStored !== false;
        document.getElementById('hook-onBatchReceived').checked = hooks.onBatchReceived === true;
        document.getElementById('hook-onBatchStored').checked = hooks.onBatchStored !== false;
        document.getElementById('hook-onError').checked = hooks.onError !== false;

        if (plugin.name === 'github') {
            document.getElementById('github-config').style.display = 'block';
            document.getElementById('gh-token').value = config.token || '';
            document.getElementById('gh-owner').value = config.owner || '';
            document.getElementById('gh-repo').value = config.repo || '';
            document.getElementById('gh-labels').value = (config.labels || []).join(', ');
            document.getElementById('gh-assignees').value = (config.assignees || []).join(', ');
            document.getElementById('gh-require-user-message').checked = config.requireUserMessage !== false;
        }
    } else {
        document.getElementById('plugin-modal-title').textContent = 'Configure Plugin';
        pluginNameSelect.disabled = false;
        document.getElementById('plugin-enabled').checked = true;

        // Set default hooks values for new plugins
        document.getElementById('hook-onInit').checked = defaultHooks.onInit;
        document.getElementById('hook-onErrorReceived').checked = defaultHooks.onErrorReceived;
        document.getElementById('hook-onErrorStored').checked = defaultHooks.onErrorStored;
        document.getElementById('hook-onBatchReceived').checked = defaultHooks.onBatchReceived;
        document.getElementById('hook-onBatchStored').checked = defaultHooks.onBatchStored;
        document.getElementById('hook-onError').checked = defaultHooks.onError;
    }

    pluginFormError.classList.remove('active');
    pluginModal.classList.add('active');
}

function handlePluginNameChange(e) {
    document.querySelectorAll('.plugin-config-section').forEach(el => el.style.display = 'none');

    if (e.target.value) {
        // Show hooks config for all plugins
        document.getElementById('hooks-config').style.display = 'block';

        if (e.target.value === 'github') {
            document.getElementById('github-config').style.display = 'block';
        }
    }
}

async function handleSavePlugin(e) {
    e.preventDefault();

    const pluginName = pluginNameSelect.value;
    const enabled = document.getElementById('plugin-enabled').checked;

    // Gather hooks configuration
    const hooks = {
        onInit: document.getElementById('hook-onInit').checked,
        onErrorReceived: document.getElementById('hook-onErrorReceived').checked,
        onErrorStored: document.getElementById('hook-onErrorStored').checked,
        onBatchReceived: document.getElementById('hook-onBatchReceived').checked,
        onBatchStored: document.getElementById('hook-onBatchStored').checked,
        onError: document.getElementById('hook-onError').checked
    };

    let config = { hooks };

    if (pluginName === 'github') {
        const token = document.getElementById('gh-token').value.trim();
        const owner = document.getElementById('gh-owner').value.trim();
        const repo = document.getElementById('gh-repo').value.trim();

        if (!token || !owner || !repo) {
            showError(pluginFormError, 'Token, Owner, and Repo are required');
            return;
        }

        config = {
            ...config,
            token,
            owner,
            repo,
            labels: document.getElementById('gh-labels').value.split(',').map(l => l.trim()).filter(Boolean),
            assignees: document.getElementById('gh-assignees').value.split(',').map(a => a.trim()).filter(Boolean),
            requireUserMessage: document.getElementById('gh-require-user-message').checked
        };
    }

    try {
        if (editingPluginId) {
            await apiCall(`/admin/plugins/${editingPluginId}`, {
                method: 'PUT',
                body: JSON.stringify({ config, enabled })
            });
        } else {
            await apiCall('/admin/plugins', {
                method: 'POST',
                body: JSON.stringify({ name: pluginName, config, enabled })
            });
        }

        closeModals();
        loadPlugins();
    } catch (error) {
        showError(pluginFormError, error.message);
    }
}

// Utilities
function closeModals() {
    clientModal.classList.remove('active');
    deleteModal.classList.remove('active');
    pluginModal.classList.remove('active');
    logDetailModal.classList.remove('active');
    editingClientId = null;
    editingPluginId = null;
    deleteTarget = null;
}

function generateSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let secret = '';
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    for (let i = 0; i < 32; i++) {
        secret += chars[array[i] % chars.length];
    }
    document.getElementById('client-shared-secret').value = secret;
}

function showError(element, message) {
    element.textContent = message;
    element.classList.add('active');
    setTimeout(() => {
        element.classList.remove('active');
    }, 5000);
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function truncate(str, len) {
    if (!str) return '';
    return str.length > len ? str.substring(0, len) + '...' : str;
}

function formatTimestamp(ts) {
    if (!ts) return '';
    const date = new Date(ts);
    return date.toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
}
