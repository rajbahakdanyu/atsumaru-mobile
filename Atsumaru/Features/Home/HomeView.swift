import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Home")
            }
            .navigationTitle("Atsumaru")
        }
    }
}