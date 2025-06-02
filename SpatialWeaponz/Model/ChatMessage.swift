//
//  ChatMessage.swift
//  SpatialWeaponz
//
//  Created by Fuad on 03/06/25.
//

import SwiftUI

struct ChatMessage: Identifiable, Codable {
    let id: UUID = UUID()
    let senderDisplayName: String
    let text: String
    var isLocalUser: Bool // To differentiate messages from self vs. others
}
