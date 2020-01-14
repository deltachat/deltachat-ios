import Foundation

protocol Searchable {
    func contains(searchText text: String) -> [ResultIndexes]
    func containsExact(searchText text: String) -> [ResultIndexes]
}

extension DcChat: Searchable {
    func contains(searchText text: String) -> [ResultIndexes] {
        fatalError("Incremental Search Not Supported")
    }

    func containsExact(searchText text: String) -> [ResultIndexes] {
        return []
    }


}
