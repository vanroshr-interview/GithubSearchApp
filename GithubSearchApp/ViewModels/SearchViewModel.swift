import Foundation
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasSearched = false
    
    private var allUsers: [User] = [] { didSet { updateUsers() } }
    private var favoriteUsers: Set<User> = []  { didSet { updateUsers() } }
    var isFavoriteViewEnabled = false  { didSet { updateUsers() } }
    
    private let networkService = NetworkService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $searchText
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .debounce(for: 0.5, scheduler: RunLoop.main)
//            .throttle(for: 3.0, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] query in
                self?.searchUsers(query: query)
            }
            .store(in: &cancellables)
    }
    
    func searchUsers(query: String) {
        guard !query.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        hasSearched = true
        
        Task {
            do {
                let users = try await networkService.searchUsers(query: query)
                
                await MainActor.run {
                    self.allUsers = users
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.allUsers = []
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func isFavorite(user: User) -> Bool {
        favoriteUsers.contains(user)
    }
    
    func toggleFavorite(for user: User) {
        if isFavorite(user: user) {
            favoriteUsers.remove(user)
        } else {
            favoriteUsers.insert(user)
        }
    }
    
    func updateUsers() {
        if isFavoriteViewEnabled {
            users = allUsers.filter { isFavorite(user: $0) }
        } else {
            users = allUsers
        }
    }
}
