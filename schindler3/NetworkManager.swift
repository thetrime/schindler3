//
//  NetworkManager.swift
//  schindler3
//
//  Created by Matt Lilley on 26/02/18.
//  Copyright © 2018 Matt Lilley. All rights reserved.
//

import Foundation

// The plan here is relatively simple
// We connect to the remote database when the sync button is pressed (later, we can connect and poll for messages)
// Initially, our sync token is 0. Save this in our local database
// When we sync, SELECT min(token) FROM sync_message. If this is > the token we have, SELECT message FROM sync_message WHERE token > (our-token) ORDER BY token
// Process each message
// Otherwise, we must do a force-sync. SELECT token, data FROM item, store_location, etc. Dump the data from our tables and use that data instead. Each data will be in some serialized, compressed format to save on row count - one row per table (per user)
// Finally, repeat the sync process with the new sync token we have retrieved. This should be inside sync_message.

// Periodically, a separate service will connect to the DB and compact it by generating a new snapshot and deleting old sync_message rows.
// Each sync_message and snapshot will have a user_id as well, just in case we want to go there in the future

// Meanwhile, every time we update our database, we call a method in here which tries to insert a sync_message on the remote DB. If this fails (eg because we have no networking connection) then these messages are queued in the local database in sync_message
// Whenever we get a connection to the DB, FIRST we sync data, THEN we send these messages. Otherwise we will bump our sync token prematurely.

// When I say 'connect to the database' it is probably better to write a very simple heroku app and just use that as a proxy. Then we can vastly simplify the logic: We can have a simple wire protocol from the client, we don't need to connect to the DB directly, etc.

class NetworkManager : NSObject, StreamDelegate {
    private let hostname: String = "localhost";
    private let port: UInt32 = 9007;
    private var dataManager: DataManager;
    private var inputStream: InputStream!
    private var outputStream: OutputStream!
    private var isSynchronized = false;
    private let maxMessageSize = 4096;
    
    init(withDataManager: DataManager) {
        dataManager = withDataManager;
        super.init();
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
            self.sync();
        })
    }
    
    public func sync() {
        // Runs on any thread. Posts updates to the dataManager as a batch on the main thread, which must then notify the list that the data has changed
        connect();
    }
    
    @discardableResult private func dispatchQueuedMessage(_ message: String, withId id: Int64) -> Bool {
        // FIXME: Try to send it. If it succeeds, delete the row. Otherwise, leave it
        return false;
    }
    
    public func queueMessage(_ message: String) {
        let id = dataManager.storeMessage(message)
        dispatchQueuedMessage(message, withId:id);
    }
    
    private func connect() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           hostname as CFString,
                                           port,
                                           &readStream,
                                           &writeStream)
        
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        
        inputStream.delegate = self
        outputStream.delegate = self
        
        inputStream.schedule(in: .main, forMode: .commonModes)
        outputStream.schedule(in: .main, forMode: .commonModes)
        
        inputStream.open()
        outputStream.open()
        
        let token = dataManager.getGlobalState();
        print("Sending token...")
        sendData("S\(token)\n");
        
        // FIXME: Wait for the reply messages. Either it will be a list of message objects or a full transfer
        // FIXME: requeue all the messages in the database by calling dispatchQueuedMessage(...) on them, in order. Stop if any of the calls return false since the network has gone again
    }
    
    private func sendData(_ message: String) {
        let data = message.data(using: .utf8)!
        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            print("Data is available...");
            readMessage(stream: aStream as! InputStream);
        case Stream.Event.endEncountered:
            print("End of stream detected")
        case Stream.Event.errorOccurred:
            print("error occurred")
        case Stream.Event.hasSpaceAvailable:
            print("has space available")
        case Stream.Event.openCompleted:
            print("Open");
        default:
            print("??")
        }
    }
    
    private func readMessageLength(from stream: InputStream) -> Int {
        var length: UInt8 = 0;
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1);
        while stream.hasBytesAvailable {
            let n = inputStream.read(buffer, maxLength: 1);
            if (n < 1) {
                return 0;
            }
            if (buffer[0] == 10) {
                break;
            }
            length = 10*length + buffer[0] - 48;
        }
        return Int(length);
    }
    
    private func readMessage(stream: InputStream) {
        let len = readMessageLength(from:stream);
        guard (len > 0) else {
            return;
        }
        var message = "";
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: len);
        var readBytes = 0;
        while stream.hasBytesAvailable && readBytes < len {
            let n = inputStream.read(buffer, maxLength: len)
            if n < 0 {
                if let _ = stream.streamError {
                    print("Error detected");
                    break
                }
            } else if (n > 0) {
                readBytes += n;
                if let fragment = String(bytesNoCopy: buffer, length: n, encoding: .utf8, freeWhenDone: true) {
                    message += fragment;
                }
            }
        }
        processMessage(message);
    }
    
    private func processMessage(_ message: String) {
        // FIXME: Process then signal that the table may need to be redrawn
        print("Message: \(message)")
    }
}
