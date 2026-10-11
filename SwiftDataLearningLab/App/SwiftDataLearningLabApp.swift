import SwiftData
import SwiftUI

@main
struct SwiftDataLearningLabApp: App {
    private let launch: Result<ModelContainer, Error>

    init() {
        launch = Result { try AppModelContainer.makeShared() }
    }

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .success(let container):
                RootView()
                    .modelContainer(container)
            case .failure(let error):
                ContainerErrorView(error: error)
            }
        }
    }
}

struct ContainerErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("The store did not open", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            VStack(alignment: .leading, spacing: 12) {
                Text("SwiftData could not create the ModelContainer. A changed model without a migration plan is the usual cause during development.")
                Text(error.localizedDescription)
                if let url = try? AppModelContainer.storeURL() {
                    Text("Store file: \(url.path)")
                        .font(.footnote)
                        .textSelection(.enabled)
                }
                Text("Delete the app from the simulator, or delete that store file, then run again. The migration lesson shows how to evolve a store on purpose.")
            }
        }
        .padding()
    }
}
