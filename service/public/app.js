// State
let authToken = null;
let clients = [];
let editingClientId = null;

// DOM Elements
const loginContainer = document.getElementById('login-container');
const adminContainer = document.getElementById('admin-container');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const logoutBtn = document.getElementById('logout-btn');
const addClientBtn = document.getElementById('add-client-btn');
const refreshBtn = document.getElementById('refresh-btn');
const clientsList = document.getElementById('clients-list');
const clientModal = document.getElementById('client-modal');
const deleteModal = document.getElementById('delete-modal');
const clientForm = document.getElementById('client-form');
const formError = document.getElementById('form-error');
const generateSecretBtn = document.getElementById('generate-secret-btn');
const confirmDeleteBtn = document.getElementById('confirm-delete-btn');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkAuth();
    setupEventListeners();
});

function setupEventListeners() {
    // Login
    loginForm.addEventListener('submit', handleLogin);
    logoutBtn.addEventListener('click', handleLogout);

    // Client management
    addClientBtn.addEventListener('click', () => openClientModal());
    refreshBtn.addEventListener('click', loadClients);
    clientForm.addEventListener('submit', handleSaveClient);
    generateSecretBtn.addEventListener('click', generateSecret);
    confirmDeleteBtn.addEventListener('click', handleDeleteClient);

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

// Authentication
function checkAuth() {
    authToken = localStorage.getItem('authToken');
    if (authToken) {
        showAdmin();
        loadClients();
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

async function loadClients() {
    try {
        clientsList.innerHTML = '<p class="loading">Loading clients...</p>';
        const data = await apiCall('/admin/clients');
        clients = data;
        renderClients();
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
            openDeleteModal(client);
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
            // Update existing client
            await apiCall(`/admin/clients/${editingClientId}`, {
                method: 'PUT',
                body: JSON.stringify({ appName, sharedSecret, enabled })
            });
        } else {
            // Create new client
            await apiCall('/admin/clients', {
                method: 'POST',
                body: JSON.stringify({ appId, appName, sharedSecret })
            });
        }

        closeModals();
        loadClients();
    } catch (error) {
        showError(formError, error.message);
    }
}

// Delete modal
function openDeleteModal(client) {
    editingClientId = client.app_id;
    document.getElementById('delete-client-name').textContent = `${client.app_name} (${client.app_id})`;
    deleteModal.classList.add('active');
}

async function handleDeleteClient() {
    try {
        await apiCall(`/admin/clients/${editingClientId}`, {
            method: 'DELETE'
        });
        closeModals();
        loadClients();
    } catch (error) {
        alert('Failed to delete client: ' + error.message);
    }
}

// Utilities
function closeModals() {
    clientModal.classList.remove('active');
    deleteModal.classList.remove('active');
    editingClientId = null;
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
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
