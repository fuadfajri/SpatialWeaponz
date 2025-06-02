//
//  ChatView.swift
//  SpatialWeaponz
//
//  Created by Fuad on 03/06/25.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    // Array of preset messages
    private let presetMessages = ["BOOM", "BANG", "PAW"]
    // State variable to hold the selected preset message
    @State private var selectedPreset: String
    
    // Initialize selectedPreset with the first message or a default
    init() {
        _selectedPreset = State(initialValue: presetMessages.first ?? "BOOM")
    }

    var body: some View {
        NavigationView {
            VStack {
                // Header: Join/Leave Button and Participant Count
                HStack {
                    Button(action: {
                        viewModel.toggleJoinLeaveSession()
                    }) {
                        Text(viewModel.isJoined ? "Leave Chat" : "Join Chat")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(viewModel.isJoined ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    Spacer()
                    Text("Participants: \(viewModel.connectedPeers.count + (viewModel.isJoined ? 1: 0))")
                        .font(.headline)
                }
                .padding()

                // Message List (ScrollViewReader and .onChange removed)
                List(viewModel.messages) { msg in
                    VStack(alignment: msg.isLocalUser ? .trailing : .leading) {
                        Text(msg.senderDisplayName)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(msg.text)
                            .padding(10)
                            .background(msg.isLocalUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .frame(maxWidth: .infinity, alignment: msg.isLocalUser ? .trailing : .leading)
                    }
                    .listRowSeparator(.hidden)
                    .id(msg.id) // id is still useful for List diffing
                }
                .listStyle(PlainListStyle())

                // Preset Message Picker and Send Button Area
                HStack {
                    Picker("Select Message", selection: $selectedPreset) {
                        ForEach(presetMessages, id: \.self) { message in
                            Text(message).tag(message)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(minWidth: 150)
                    .padding(.leading)

                    Button(action: {
                        viewModel.sendMessage(selectedPreset)
                    }) {
                        Text("Send")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(!viewModel.isJoined || selectedPreset.isEmpty)
                    .padding(.trailing)
                }
                .padding(.vertical)
            }
            .navigationTitle("MPC Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
