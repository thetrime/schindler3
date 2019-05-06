//
//  NetworkManager.swift
//  schindler3
//
//  Created by Matt Lilley on 26/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import Foundation
import Starscream


// New plan:
// The application only talks to the data manager. It tells the data manager when the user has done something like add an item
// The data manager stores it locally, and queues a message to advise the server. This is transparent to the application - it
// doesn't know about the network-based database at all.
// Additionally, the network manager may receive unsolicited information from the server. This is relayed to the data manager,
// which updates the database, and the data manager then advises the application that the model has changed.


class NetworkManager : NSObject, WebSocketDelegate {
    
    
    static let hostname: String = "schindlerx.strangled.net";
    static let port: UInt32 = 9008;
    private let socketProtocol = "wss"
 
 //   private let hostname: String = "192.168.1.10";
//    private let port: UInt32 = 9007;
//    private let socketProtocol = "ws"

    private var dataManager: DataManager;
    private var socket: WebSocket!
    private var isSynchronized = false;
    private let maxMessageSize = 4096;
    private var generation = 0;
    
    init(withDataManager: DataManager) {
        dataManager = withDataManager;
        super.init();
        let url = URL(string: "\(socketProtocol)://\(NetworkManager.hostname):\(NetworkManager.port)/ws")
        socket = WebSocket(url: url!)
        socket.delegate = self
        if socketProtocol == "wss" {
            if let url = Bundle.main.url(forResource: NetworkManager.hostname, withExtension: "der") {
                if let data = try? Data(contentsOf:url) {
                    print("SSL pinning enabled")
                    socket.security = SSLSecurity(certs: [SSLCert(data: data)], usePublicKeys: true)
                } else {
                    print("Failed to load certificate")
                }
            } else {
                print("No such certificate")
            }
        }
        socket.disableSSLCertValidation = true
        print("Connecting to \(url)")
        socket.connect()
    }
    
    public func sync() {
        // Runs on any thread. Posts updates to the dataManager as a batch on the main thread, which must then notify the list that the data has changed
        // FIXME: Ignored
    }
    
    public func queueMessage(_ message: [String:Any]) {
        guard let messageData = try? JSONSerialization.data(withJSONObject: message, options: .prettyPrinted) else {
            return
        }
        guard let messageText = String(data:messageData, encoding:.utf8) else {
            return
        }
        let id = dataManager.storeMessage(messageText)
        print("Stored \(id)")
        attemptMessageTransmission(messageText:messageText, id:id)
    }
    
    @discardableResult private func attemptMessageTransmission(messageText: String, id: Int64) -> Bool {
        print("Sending message \(messageText)")
        if (socket.isConnected) {
            let currentGen = generation;
            socket.write(string: messageText)
            // If successful, delete the message identified by id. Otherwise leave it alone (FIXME: How to tell?)
            if (generation == currentGen) {
                dataManager.deleteMessage(id)
                print("Message was sent successfully")
                return true
            } else {
                print("Message was possibly not sent successfully")
            }
        }
        return false
    }
    
    private func attemptImmediateTransmission(ofObject object:[String:Any]) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted) else {
            return false
        }
        guard let text = String(data:data, encoding:.utf8) else {
            return false
        }
        socket.write(string: text)
        return true
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        generation = generation + 1
        print("websocket is connected")
        // Ok, now log in
        // FIXME: Obviously we need to ask for the password at some point and save it somewhere
        if !attemptImmediateTransmission(ofObject:["user_id": dataManager.userId, "password": dataManager.password]) {
            return;
        }
        
        // Good. Now re-send any messages we may have missed
        for row in dataManager.missedMessages() {
            if let messageText = row["message"] as? String {
                if let id = row["message_id"] as? Int64 {
                  print("Resending: \(id)")
                  if !attemptMessageTransmission(messageText: messageText, id:id) {
                       /* Then we are disconnected, so give up. We will try again momentarily */
                       return
                   }
                }
                else {
                    print("Could not get message_id as int64")
                }
            }
        }
        // If we get here, then we sent our backlog. We can now send a sync message directly (do not queue this)
        attemptImmediateTransmission(ofObject: ["opcode":"sync", "timestamp":dataManager.syncPoint()])
        dataManager.indicateConnected()
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        dataManager.indicateDisconnected()
        generation = generation + 1
        print("websocket is disconnected: \(error?.localizedDescription)")
        tryToReconnect();
    }
    
    private func tryToReconnect() {
        if Reachability.isConnectedToNetwork() {
            socket.connect();
        } else {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: .now() + 2, execute: {
                self.tryToReconnect()
            })
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        let data = text.data(using: .utf8)!
        if let json = try? JSONSerialization.jsonObject(with: data, options : .allowFragments) as! Dictionary<String,Any> {
            guard let opcode = json["opcode"] as? String else {
                return
            }
            dataManager.handleUnsolicitedMessage(withOpcode:opcode, data:json)            
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("got some data: \(data.count)")
    }
}
