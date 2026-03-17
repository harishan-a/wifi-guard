import SwiftUI

struct DiagnosticsView: View {
    @State private var diagnostics = NetworkDiagnostics()
    @State private var report: NetworkDiagnostics.Report?
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Network Diagnostics")
                    .font(.title2.bold())
                Spacer()
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Run Again") {
                        Task { await runDiagnostics() }
                    }
                }
            }

            if let report {
                Text("macOS \(report.macOSVersion) — \(report.timestamp.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if report.issueCount > 0 {
                    Text("\(report.issueCount) issue(s) found")
                        .foregroundStyle(.red)
                        .font(.headline)
                } else {
                    Text("No issues detected")
                        .foregroundStyle(.green)
                        .font(.headline)
                }

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(report.findings) { finding in
                            findingRow(finding)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Run Diagnostics",
                    systemImage: "stethoscope",
                    description: Text("Click 'Run Again' or wait for automatic scan")
                )
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await runDiagnostics()
        }
    }

    private func runDiagnostics() async {
        isRunning = true
        report = await diagnostics.runDiagnostics()
        isRunning = false
    }

    @ViewBuilder
    private func findingRow(_ finding: NetworkDiagnostics.Finding) -> some View {
        HStack(alignment: .top, spacing: 8) {
            severityBadge(finding.severity)
            VStack(alignment: .leading, spacing: 2) {
                Text("[\(finding.category)] \(finding.message)")
                    .font(.body)
                if let detail = finding.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func severityBadge(_ severity: NetworkDiagnostics.Severity) -> some View {
        Text(severity.rawValue)
            .font(.caption.bold().monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(severityColor(severity).opacity(0.2))
            .foregroundStyle(severityColor(severity))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func severityColor(_ severity: NetworkDiagnostics.Severity) -> Color {
        switch severity {
        case .ok: return .green
        case .warning: return .orange
        case .critical: return .red
        case .info: return .blue
        }
    }
}
