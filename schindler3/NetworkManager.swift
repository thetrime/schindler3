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
