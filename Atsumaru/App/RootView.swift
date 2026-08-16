import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") { HomeView() }
            Tab("Browse", systemImage: "square.grid.2x2.fill") { BrowseView() }
            Tab("Library", systemImage: "books.vertical.fill") { LibraryView() }
            Tab("Downloads", systemImage: "arrow.down.circle.fill") { DownloadsView() }
            Tab("Forum", systemImage: "bubble.left.and.text.bubble.right.fill") { ForumView() }
            Tab("Profile", systemImage: "person.crop.circle.fill") { AccountView() }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}