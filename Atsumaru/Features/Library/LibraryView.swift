import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Library")
            }
            .navigationTitle("Library")
        }
    }
}