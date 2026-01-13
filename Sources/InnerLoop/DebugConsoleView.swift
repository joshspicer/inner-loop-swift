import SwiftUI

/// A beautiful full-screen debug console view
@available(iOS 15.0, *)
public struct DebugConsoleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DebugConsoleViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: LogLevelFilter = .all
    @State private var showingMessageInput = false
    @State private var userMessage = ""
    @State private var showingSendConfirmation = false
    @State private var showingSettings = false
    
    public init() {}
    
    enum LogLevelFilter: String, CaseIterable {
        case all = "All"
        case debug = "Debug"
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        
        var color: Color {
            switch self {
            case .all: return .primary
            case .debug: return .gray
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    
    var filteredLogs: [LogEntry] {
        viewModel.logs.filter { entry in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .debug:
                matchesFilter = entry.level == "DEBUG"
            case .info:
                matchesFilter = entry.level == "INFO"
            case .warning:
                matchesFilter = entry.level == "WARNING"
            case .error:
                matchesFilter = entry.level == "ERROR"
            }
            
            let matchesSearch = searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                (entry.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            return matchesFilter && matchesSearch
        }
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats header
                statsHeader
                
                // Filter pills
                filterPills
                
                // Search bar
                searchBar
                
                // Log list
                logList
                
                // Action bar
                actionBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                        }
                        Menu {
                            Button(action: { viewModel.refreshLogs() }) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            Button(action: { viewModel.clearLogs() }) {
                                Label("Clear Logs", systemImage: "trash")
                            }
                            Button(action: { viewModel.testErrorReport() }) {
                                Label("Test Error", systemImage: "exclamationmark.triangle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingMessageInput) {
                messageInputSheet
            }
            .sheet(isPresented: $showingSettings) {
                EndpointSettingsView()
            }
            .alert("Logs Sent", isPresented: $showingSendConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your logs have been sent successfully.")
            }
        }
        .onAppear {
            viewModel.refreshLogs()
        }
    }
    
    private var statsHeader: some View {
        VStack(spacing: 8) {
            // Connection status bar
            HStack {
                Image(systemName: EndpointManager.shared.isEnabled ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(EndpointManager.shared.isEnabled ? .green : .gray)
                Text(EndpointManager.shared.isEnabled ? EndpointManager.shared.endpointString : "Not Connected")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(EndpointManager.shared.isEnabled ? .primary : .secondary)
                Spacer()
                Button(action: { showingSettings = true }) {
                    Text("Configure")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            
            // Stats cards
            HStack(spacing: 16) {
                StatCard(
                    title: "Total",
                    value: "\(viewModel.logs.count)",
                    icon: "doc.text",
                    color: .blue
                )
                StatCard(
                    title: "Errors",
                    value: "\(viewModel.errorCount)",
                    icon: "exclamationmark.circle",
                    color: .red
                )
                StatCard(
                    title: "Warnings",
                    value: "\(viewModel.warningCount)",
                    icon: "exclamationmark.triangle",
                    color: .orange
                )
                StatCard(
                    title: "Buffered",
                    value: "\(viewModel.bufferSize)",
                    icon: "tray",
                    color: .purple
                )
            }
        }
        .padding()
    }
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LogLevelFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        color: filter.color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search logs...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private var logList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, entry in
                    LogEntryRow(entry: entry)
                        .id(index)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .refreshable {
                viewModel.refreshLogs()
            }
        }
    }
    
    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: { showingMessageInput = true }) {
                HStack {
                    Image(systemName: "text.bubble")
                    Text("Add Message")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: {
                viewModel.sendLogs()
                showingSendConfirmation = true
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Send")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var messageInputSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Describe what happened")
                    .font(.headline)
                    .padding(.top)
                
                TextEditor(text: $userMessage)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                Text("This message will be included with your logs to help diagnose the issue.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    viewModel.sendLogs(withMessage: userMessage)
                    userMessage = ""
                    showingMessageInput = false
                    showingSendConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send with Message")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Add Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingMessageInput = false
                    }
                }
            }
        }
    }
}

// MARK: - Endpoint Settings View

@available(iOS 15.0, *)
struct EndpointSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EndpointSettingsViewModel()
    @State private var showingCustomInput = false
    
    var body: some View {
        NavigationView {
            Form {
                // Enable/Disable Section
                Section {
                    Toggle("Enable Remote Logging", isOn: $viewModel.isEnabled)
                        .tint(.green)
                } header: {
                    Text("Remote Logging")
                } footer: {
                    Text("When enabled, logs will be sent to the configured endpoint.")
                }
                
                // Current Endpoint Section
                if viewModel.isEnabled {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Endpoint")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(viewModel.endpointString)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            Circle()
                                .fill(viewModel.isEnabled ? Color.green : Color.gray)
                                .frame(width: 10, height: 10)
                        }
                    }
                    
                    // Quick Select Section
                    Section {
                        ForEach(viewModel.commonEndpoints, id: \.host) { endpoint in
                            Button(action: {
                                viewModel.selectEndpoint(host: endpoint.host, port: endpoint.port)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(endpoint.name)
                                            .foregroundColor(.primary)
                                        Text("\(endpoint.host):\(endpoint.port)")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if viewModel.host == endpoint.host && viewModel.port == endpoint.port {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        
                        Button(action: { showingCustomInput = true }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                Text("Custom Endpoint...")
                                    .foregroundColor(.blue)
                            }
                        }
                    } header: {
                        Text("Quick Select")
                    }
                    
                    // Manual Configuration Section
                    Section {
                        HStack {
                            Text("Host")
                                .foregroundColor(.secondary)
                            TextField("192.168.1.100", text: $viewModel.host)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                        }
                        
                        HStack {
                            Text("Port")
                                .foregroundColor(.secondary)
                            TextField("8080", text: $viewModel.portString)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                        }
                    } header: {
                        Text("Manual Configuration")
                    }
                    
                    // Test Connection Section
                    Section {
                        Button(action: { viewModel.testConnection() }) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Test Connection")
                                Spacer()
                                if viewModel.isTesting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if let success = viewModel.lastTestResult {
                                    Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(success ? .green : .red)
                                }
                            }
                        }
                        .disabled(viewModel.isTesting)
                        
                        if let message = viewModel.testResultMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(viewModel.lastTestResult == true ? .green : .red)
                        }
                    }
                    
                    // Reset Section
                    Section {
                        Button(action: { viewModel.resetToDefaults() }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset to Defaults")
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Endpoint Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Custom Endpoint", isPresented: $showingCustomInput) {
                TextField("192.168.1.100:8080", text: $viewModel.customEndpointInput)
                    .autocapitalization(.none)
                Button("Cancel", role: .cancel) { }
                Button("Set") {
                    viewModel.setCustomEndpoint()
                }
            } message: {
                Text("Enter host:port (e.g., 192.168.1.100:8080)")
            }
        }
    }
}

// MARK: - Endpoint Settings ViewModel

@available(iOS 15.0, *)
class EndpointSettingsViewModel: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            EndpointManager.shared.isEnabled = isEnabled
        }
    }
    
    @Published var host: String {
        didSet {
            EndpointManager.shared.host = host
        }
    }
    
    @Published var portString: String {
        didSet {
            if let port = Int(portString) {
                EndpointManager.shared.port = port
            }
        }
    }
    
    @Published var isTesting = false
    @Published var lastTestResult: Bool?
    @Published var testResultMessage: String?
    @Published var customEndpointInput = ""
    
    var port: Int {
        Int(portString) ?? EndpointManager.defaultPort
    }
    
    var endpointString: String {
        "\(host):\(port)"
    }
    
    var commonEndpoints: [(name: String, host: String, port: Int)] {
        EndpointManager.shared.getCommonEndpoints()
    }
    
    init() {
        self.isEnabled = EndpointManager.shared.isEnabled
        self.host = EndpointManager.shared.host
        self.portString = String(EndpointManager.shared.port)
    }
    
    func selectEndpoint(host: String, port: Int) {
        self.host = host
        self.portString = String(port)
        Logger.shared.info("EndpointSettings", "Selected endpoint: \(host):\(port)")
    }
    
    func setCustomEndpoint() {
        EndpointManager.shared.setEndpoint(from: customEndpointInput)
        self.host = EndpointManager.shared.host
        self.portString = String(EndpointManager.shared.port)
        customEndpointInput = ""
    }
    
    func resetToDefaults() {
        EndpointManager.shared.resetToDefaults()
        self.host = EndpointManager.shared.host
        self.portString = String(EndpointManager.shared.port)
        self.isEnabled = EndpointManager.shared.isEnabled
    }
    
    func testConnection() {
        guard let url = URL(string: "http://\(host):\(port)/health") else {
            testResultMessage = "Invalid URL"
            lastTestResult = false
            return
        }
        
        isTesting = true
        lastTestResult = nil
        testResultMessage = nil
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isTesting = false
                
                if let error = error {
                    self?.lastTestResult = false
                    self?.testResultMessage = "Connection failed: \(error.localizedDescription)"
                    Logger.shared.warning("EndpointSettings", "Connection test failed: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        self?.lastTestResult = true
                        self?.testResultMessage = "Connected successfully!"
                        Logger.shared.info("EndpointSettings", "Connection test succeeded")
                    } else {
                        self?.lastTestResult = false
                        self?.testResultMessage = "Server returned status \(httpResponse.statusCode)"
                        Logger.shared.warning("EndpointSettings", "Connection test returned \(httpResponse.statusCode)")
                    }
                } else {
                    self?.lastTestResult = false
                    self?.testResultMessage = "Unknown error"
                }
            }
        }.resume()
    }
}

// MARK: - Supporting Views

@available(iOS 15.0, *)
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

@available(iOS 15.0, *)
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.15))
                .cornerRadius(16)
        }
    }
}

@available(iOS 15.0, *)
struct LogEntryRow: View {
    let entry: LogEntry
    @State private var isExpanded = false
    
    private var levelColor: Color {
        switch entry.level {
        case "DEBUG": return .gray
        case "INFO": return .blue
        case "WARNING": return .orange
        case "ERROR": return .red
        default: return .primary
        }
    }
    
    private var levelIcon: String {
        switch entry.level {
        case "DEBUG": return "ant"
        case "INFO": return "info.circle"
        case "WARNING": return "exclamationmark.triangle"
        case "ERROR": return "xmark.circle"
        default: return "circle"
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // Level indicator
                Image(systemName: levelIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(levelColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Category and timestamp
                    HStack {
                        if let category = entry.category {
                            Text(category)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(levelColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(levelColor.opacity(0.15))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        Text(timeFormatter.string(from: entry.timestamp))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    // Message
                    Text(entry.message)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    // File info (when expanded)
                    if isExpanded {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.system(size: 9))
                            Text("\(entry.file):\(entry.line)")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - ViewModel

@available(iOS 15.0, *)
class DebugConsoleViewModel: ObservableObject {
    @Published var logs: [LogEntry] = []
    @Published var bufferSize: Int = 0
    
    var errorCount: Int {
        logs.filter { $0.level == "ERROR" }.count
    }
    
    var warningCount: Int {
        logs.filter { $0.level == "WARNING" }.count
    }
    
    func refreshLogs() {
        logs = LogBatcher.shared.getLogs()
        bufferSize = LogBatcher.shared.getBufferSize()
    }
    
    func clearLogs() {
        LogBatcher.shared.clearBuffer()
        refreshLogs()
    }
    
    func sendLogs(withMessage message: String? = nil) {
        LogBatcher.shared.sendBatch(userMessage: message)
        Logger.shared.info("DebugConsole", "Logs sent\(message != nil ? " with message" : "")")
    }
    
    func testErrorReport() {
        ErrorHandler.shared.report(message: "Test error from Debug Console")
        Logger.shared.info("DebugConsole", "Test error reported")
        refreshLogs()
    }
}

// MARK: - Hosting Controller

@available(iOS 15.0, *)
public class DebugConsoleHostingController: UIHostingController<DebugConsoleView> {
    public init() {
        super.init(rootView: DebugConsoleView())
        modalPresentationStyle = .fullScreen
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
