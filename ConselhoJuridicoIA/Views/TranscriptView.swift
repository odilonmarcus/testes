import SwiftUI

struct TranscriptView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.entries.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.entries) { entry in
                                DebateCard(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(24)
                    }
                    .onChange(of: viewModel.entries.count) { _ in
                        if let last = viewModel.entries.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            if !viewModel.finalSynthesis.isEmpty {
                Divider()
                HStack {
                    Text("Parecer concluído")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        viewModel.copyFinal()
                    } label: {
                        Label("Copiar", systemImage: "doc.on.doc")
                    }
                    Button {
                        viewModel.exportFinalAsPDF()
                    } label: {
                        Label("Exportar PDF", systemImage: "square.and.arrow.down")
                    }
                }
                .padding(12)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("O debate aparecerá aqui")
                .font(.title3.weight(.semibold))
            Text("GPT constrói a tese, Claude faz o contraditório e o relator consolida os pontos fortes, riscos e lacunas.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct DebateCard: View {
    let entry: DebateEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                Text(entry.role)
                    .font(.headline)
                if let round = entry.round {
                    Text("Rodada \(round)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                Text(entry.speaker.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(entry.content)
                .textSelection(.enabled)
                .font(.body)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var icon: String {
        switch entry.speaker {
        case .gpt: return "brain.head.profile"
        case .claude: return "scale.3d"
        case .system: return "doc.text.magnifyingglass"
        }
    }

    private var accent: Color {
        switch entry.speaker {
        case .gpt: return .blue
        case .claude: return .purple
        case .system: return .green
        }
    }

    private var background: Color {
        switch entry.speaker {
        case .system: return Color(nsColor: .controlBackgroundColor)
        default: return Color(nsColor: .windowBackgroundColor)
        }
    }
}
