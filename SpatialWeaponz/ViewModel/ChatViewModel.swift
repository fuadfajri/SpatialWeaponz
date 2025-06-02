//
//  ChatViewModel.swift
//  SpatialWeaponz
//
//  Created by Fuad on 03/06/25.
//

import SwiftUI
import MultipeerConnectivity

class ChatViewModel: NSObject, ObservableObject {
    // Published properties to update the UI
    @Published var messages: [ChatMessage] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var isJoined: Bool = false
    @Published var currentDeviceName: String = UIDevice.current.name

    var peerID: MCPeerID!
    var mcSession: MCSession!
    var mcAdvertiserAssistant: MCNearbyServiceAdvertiser!
    var mcNearbyServiceBrowser: MCNearbyServiceBrowser!

    // Service type must be a unique string, 1-15 chars, containing only lowercase letters, numbers, and hyphens.
    private let serviceType = "sn-mpc-chat"
    
    // To track peers that have connected at least once in this session to differentiate initial connections from reconnections for logging
    private var everConnectedPeers: Set<MCPeerID> = []


    override init() {
        super.init()
        setupConnectivity()
    }

    private func setupConnectivity() {
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self

        mcAdvertiserAssistant = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        mcAdvertiserAssistant.delegate = self

        mcNearbyServiceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        mcNearbyServiceBrowser.delegate = self
    }

    // MARK: - Public Methods

    func toggleJoinLeaveSession() {
        isJoined.toggle()
        if isJoined {
            startHosting()
            startBrowsing()
            log("Session Joined. Advertising and Browsing started.")
            // everConnectedPeers is intentionally not reset here to track reconnections
            // across local join/leave cycles for the same ChatViewModel instance.
        } else {
            stopHosting()
            stopBrowsing()
            mcSession.disconnect()
            DispatchQueue.main.async {
                self.connectedPeers = []
                self.messages.append(ChatMessage(senderDisplayName: "System", text: "Left the chat.", isLocalUser: true))
            }
            log("Session Left. Advertising and Browsing stopped. Disconnected.")
        }
    }

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard isJoined else {
            log("Cannot send message, not joined to a session.")
            return
        }

        let chatMessage = ChatMessage(senderDisplayName: peerID.displayName, text: text, isLocalUser: true)
        
        DispatchQueue.main.async {
            self.messages.append(chatMessage) // Show local message immediately
        }

        if !mcSession.connectedPeers.isEmpty {
            do {
                let data = try JSONEncoder().encode(chatMessage)
                try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
                log("Message sent: \(text)")
            } catch {
                log("Error sending message: \(error.localizedDescription)")
            }
        } else {
            log("No connected peers to send message to.")
        }
    }

    // MARK: - MPC Control

    private func startHosting() {
        mcAdvertiserAssistant.startAdvertisingPeer()
        log("Started Advertising.")
    }

    private func stopHosting() {
        mcAdvertiserAssistant.stopAdvertisingPeer()
        log("Stopped Advertising.")
    }

    private func startBrowsing() {
        mcNearbyServiceBrowser.startBrowsingForPeers()
        log("Started Browsing for peers.")
    }

    private func stopBrowsing() {
        mcNearbyServiceBrowser.stopBrowsingForPeers()
        log("Stopped Browsing for peers.")
    }
    
    private func log(_ message: String) {
        // In a real app, you might use a more sophisticated logging system
        print("[ChatViewModel] \(message)")
    }
}

// MARK: - MCSessionDelegate
extension ChatViewModel: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                // Check if this peer is already in our connectedPeers list.
                // This handles potential redundant .connected events from MCSession.
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                    
                    // Log whether it's a first-time connection or a reconnection for this session instance
                    if self.everConnectedPeers.contains(peerID) {
                        self.log("\(peerID.displayName) reconnected.")
                    } else {
                        self.log("\(peerID.displayName) connected (first time this session).")
                    }
                    self.everConnectedPeers.insert(peerID) // Track that this peer has now been connected
                    
                    // Add a system message to the chat UI
                    self.messages.append(ChatMessage(senderDisplayName: "System", text: "\(peerID.displayName) has connected.", isLocalUser: false))
                } else {
                    // If already in connectedPeers, it might be a duplicate event, log for debugging if needed
                    // self.log("Received redundant connected event for already connected peer: \(peerID.displayName)")
                }

            case .connecting:
                self.log("\(peerID.displayName) connecting...")

            case .notConnected:
                if let index = self.connectedPeers.firstIndex(of: peerID) {
                    self.connectedPeers.remove(at: index)
                    self.messages.append(ChatMessage(senderDisplayName: "System", text: "\(peerID.displayName) has disconnected.", isLocalUser: false))
                    self.log("\(peerID.displayName) disconnected.")
                    // Note: peerID remains in everConnectedPeers to identify future reconnections.
                }
                if self.connectedPeers.isEmpty && self.isJoined {
                    // Optionally handle this case, e.g., if all peers disconnect while session is active
                    self.log("All peers have disconnected.")
                }

            @unknown default:
                self.log("Unknown state received: \(state) for peer \(peerID.displayName)")
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            do {
                var receivedMessage = try JSONDecoder().decode(ChatMessage.self, from: data)
                receivedMessage.isLocalUser = false // Mark as received
                self.messages.append(receivedMessage)
                self.log("Message received from \(peerID.displayName): \(receivedMessage.text)")
            } catch {
                self.log("Error decoding message: \(error.localizedDescription)")
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        log("Received stream (not handled).")
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        log("Started receiving resource (not handled): \(resourceName)")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        log("Finished receiving resource (not handled): \(resourceName)")
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension ChatViewModel: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        if isJoined {
            invitationHandler(true, self.mcSession)
            log("Accepted invitation from \(peerID.displayName).")
        } else {
            invitationHandler(false, nil)
            log("Rejected invitation from \(peerID.displayName) because not in a session.")
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        log("Advertiser did not start: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension ChatViewModel: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Invite peer if we are joined, they are not already connected/connecting, and session is not full.
        let isAlreadyConnectingOrConnected = mcSession.connectedPeers.contains(peerID) ||
                                            (mcSession.delegate as? ChatViewModel)?.connectedPeers.contains(peerID) == true // Check our view model's list as well
        
        if isJoined && !isAlreadyConnectingOrConnected && mcSession.connectedPeers.count < 7 { // MCSession has a limit of 8 peers including self
            log("Found peer: \(peerID.displayName). Inviting.")
            browser.invitePeer(peerID, to: self.mcSession, withContext: nil, timeout: 10)
        } else if !isJoined {
            log("Found peer: \(peerID.displayName), but not inviting as we are not in a session.")
        } else if isAlreadyConnectingOrConnected {
            log("Found peer: \(peerID.displayName), but already connected or connecting.")
        } else if mcSession.connectedPeers.count >= 7 {
            log("Found peer: \(peerID.displayName), but session is full.")
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        log("Lost peer (via browser): \(peerID.displayName). Disconnection handled by session delegate.")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        log("Browser did not start: \(error.localizedDescription)")
    }
}

