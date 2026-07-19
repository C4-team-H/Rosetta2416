import SwiftUI

struct AlbumBookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AlbumBookViewModel()

    var body: some View {
        NavigationSplitView {
            List(viewModel.filteredLabels, id: \.self) { label in
                Button {
                    viewModel.selectedLabel = label
                } label: {
                    Text(label.uppercased())
                        .font(GameFont.caption1Bold)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .tag(label)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search 157 references")
            .navigationTitle("Album Book")
        } detail: {
            ZStack {
                Color(red: 0.035, green: 0.055, blue: 0.09).ignoresSafeArea()
                VStack(spacing: 24) {
                    Image(viewModel.selectedLabel)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 420, maxHeight: 420)
                        .padding(24)
                        .background(.white, in: .rect(cornerRadius: 22))

                    Text(viewModel.selectedLabel.uppercased())
                        .font(GameFont.title2Bold)
                        .foregroundStyle(.white)
                }
                .padding(32)
            }
            .navigationTitle("Drawing Reference")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(GameFont.caption1Bold)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }
}
