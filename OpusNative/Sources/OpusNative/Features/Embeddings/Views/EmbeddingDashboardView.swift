import SwiftUI
import SwiftData

struct EmbeddingDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    let diContainer: AppDIContainer
    
    init(diContainer: AppDIContainer) {
        self.diContainer = diContainer
    }
    
    var body: some View {
        // Replaced the 5-tab layout with a unified workspace
        EmbeddingWorkspaceView(diContainer: diContainer)
            .navigationTitle("Embeddings Workspace")
    }
}
