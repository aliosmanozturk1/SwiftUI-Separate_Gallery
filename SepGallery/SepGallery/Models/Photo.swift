import Foundation
import UIKit

struct Photo: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let fileExtension: String
    let createdAt: Date
    
    init(id: UUID = UUID(), fileName: String, fileExtension: String = "jpg", createdAt: Date = Date()) {
        self.id = id
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.createdAt = createdAt
    }
} 