:-module(database,
         [login/2,
          import_from_old_database/1,
          item_exists/4,
          store_exists/4,
          store_located_at/6,
          item_added_to_list/4,
          item_deleted_from_list/4,
          item_located_in_aisle/6,
          item_removed_from_aisle/5,
          sync_message/4,
          prepare_database/0,
          get_connection/1]).

:- use_module(library(odbc)).


get_connection(Connection):-
        with_mutex(connection_mutex,
                   get_connection_1(Connection)).

:-thread_local(cached_connection/1).
get_connection_1(Connection):-
        cached_connection(Connection), !.
get_connection_1(Connection):-
        odbc_connect(-,
                     Connection,
                     [driver_string('DRIVER={Sqlite3};Database=schindler3.db;FKSupport=True'),
                      silent(false),
                      null({null}),
                      auto_commit(true)]),
        assert(cached_connection(Connection)).

prepare_database:-
        get_connection(Connection),
        ( catch(odbc_query(Connection, 'SELECT version FROM schema', row(Version)), _, Version = 0)->
            true
        ; otherwise->
            Version = 0
        ),
        upgrade_schema(Connection, Version).

upgrade_schema(Connection, From):-
        upgrade_schema_from(Connection, From),
        NewVersion is From + 1,
        !,
        upgrade_schema(Connection, NewVersion).

upgrade_schema(Connection, LastVersion):-
        format(atom(SQL), 'UPDATE schema SET version = ~w', [LastVersion]),
        odbc_query(Connection, SQL, _),
        odbc_end_transaction(Connection, commit).

upgrade_schema_from(Connection, 0):-
        ignore(odbc_query(Connection, 'CREATE TABLE schema(version INTEGER)', _)),
        odbc_query(Connection, 'INSERT INTO schema(version) VALUES (1)', _),
        ignore(odbc_query(Connection, 'CREATE TABLE item(user_id VARCHAR, item_id VARCHAR, deleted INTEGER, last_updated BIGINTEGER, PRIMARY KEY(user_id, item_id))', _)),
        ignore(odbc_query(Connection, 'CREATE TABLE list_entry(user_id VARCHAR, item_id VARCHAR, deleted INTEGER, last_updated BIGINTEGER, PRIMARY KEY(user_id, item_id), FOREIGN KEY(user_id, item_id) REFERENCES item(user_id, item_id))', _)),
        ignore(odbc_query(Connection, 'CREATE TABLE store(user_id VARCHAR, store_id VARCHAR, latitude VARCHAR, longitude VARCHAR, deleted INTEGER, last_updated BIGINTEGER, PRIMARY KEY(user_id, store_id))', _)),
        ignore(odbc_query(Connection, 'CREATE TABLE aisle_item(user_id VARCHAR, item_id VARCHAR, store_id VARCHAR, aisle_id VARCHAR, deleted INTEGER, last_updated BIGINTEGER, FOREIGN KEY(user_id, item_id) REFERENCES item(user_id, item_id), FOREIGN KEY(user_id, store_id) REFERENCES store(user_id, store_id), UNIQUE(user_id, item_id, store_id))', _)),
        % FIXME: Hack
        odbc_query(Connection, 'INSERT INTO STORE(user_id, store_id, last_updated) VALUES (\'matt\', \'Home\', -1)', _).

upgrade_schema_from(Connection, 1):-
        ignore(odbc_query(Connection, 'CREATE TABLE user(user_id VARCHAR, password VARCHAR)', _)),
        odbc_query(Connection, 'INSERT INTO user(user_id, password) VALUES (\'matt\', \'notverysecretatall\')', _).

build_types([], []):- !.
build_types([Value|Values], [Type|Types]):-
        value_type(Value, Type),
        build_types(Values, Types).

value_type(Value, bigint):-
        integer(Value), !.
value_type(_, default).

state_change(SQL, Parameters, DidUpdate):-
        get_connection(Connection),
        build_types(Parameters, Defaults),
        ( setup_call_cleanup(odbc_prepare(Connection, SQL, Defaults, Statement, []),
                             odbc_execute(Statement, Parameters, Result),
                             odbc_free_statement(Statement))->
            ( Result = affected(0)->
                DidUpdate = false
            ; otherwise->
                DidUpdate = true
            )
        ; otherwise->
            DidUpdate = false
        ).

select(SQL, Parameters, Selections):-
        get_connection(Connection),
        build_types(Parameters, Defaults),
        setup_call_cleanup(odbc_prepare(Connection, SQL, Defaults, Statement, []),
                           odbc_execute(Statement, Parameters, Result),
                           odbc_free_statement(Statement)),
        Result =.. [row|Selections].


item_exists(UserId, ItemId, Timestamp, DidUpdate):-
        state_change('INSERT INTO item(user_id, item_id, deleted, last_updated) VALUES (?, ?, 0, ?) ON CONFLICT(user_id, item_id) DO UPDATE SET deleted = 0, last_updated = ? WHERE last_updated < ? AND item_id = ? AND user_id = ?', [UserId, ItemId, Timestamp, Timestamp, Timestamp, ItemId, UserId], DidUpdate).


store_exists(UserId, StoreId, Timestamp, DidUpdate):-
        state_change('INSERT INTO store(user_id, store_id, deleted, last_updated) VALUES (?, ?, 0, ?) ON CONFLICT(user_id, store_id) DO UPDATE SET deleted = 0, last_updated = ? WHERE last_updated < ? AND store_id = ? AND user_id = ?', [UserId, StoreId, Timestamp, Timestamp, Timestamp, StoreId, UserId], DidUpdate).

store_located_at(UserId, StoreId, Latitude, Longitude, Timestamp, DidUpdate):-
        state_change('INSERT INTO store(user_id, store_id, latitude, longitude, deleted, last_updated) VALUES (?, ?, ?, ?, 0, ?) ON CONFLICT(user_id, store_id) DO UPDATE SET latitude = ?, longitude = ?, deleted = 0, last_updated = ? WHERE last_updated < ? AND store_id = ? AND user_id = ?',
                     [UserId, StoreId, Latitude, Longitude, Timestamp, Latitude, Longitude, Timestamp, Timestamp, StoreId, UserId],
                     DidUpdate).

item_added_to_list(UserId, ItemId, Timestamp, DidUpdate):-
        item_exists(UserId, ItemId, Timestamp, _),
        state_change('INSERT INTO list_entry(user_id, item_id, deleted, last_updated) VALUES (?, ?, 0, ?) ON CONFLICT(user_id, item_id) DO UPDATE SET deleted = 0, last_updated = ? WHERE last_updated < ? AND item_id = ? AND user_id = ?',
                     [UserId, ItemId, Timestamp, Timestamp, Timestamp, ItemId, UserId],
                     DidUpdate).

item_deleted_from_list(UserId, ItemId, Timestamp, DidUpdate):-
        state_change('UPDATE list_entry SET deleted = 0, last_updated = ? WHERE item_id = ? AND last_updated < ? AND user_id = ?',
                     [Timestamp, ItemId, Timestamp, UserId],
                     DidUpdate).

item_located_in_aisle(UserId, ItemId, StoreId, AisleId, Timestamp, DidUpdate):-
        item_exists(UserId, ItemId, Timestamp, _),
        store_exists(UserId, StoreId, Timestamp, _),
        state_change('INSERT INTO aisle_item(user_id, item_id, store_id, aisle_id, deleted, last_updated) VALUES (?, ?, ?, ?, 0, ?) ON CONFLICT(user_id, item_id, store_id) DO UPDATE SET aisle_id = ?, deleted = 0, last_updated = ? WHERE last_updated < ? AND item_id = ? AND store_id = ? AND user_id = ?',
                     [UserId, ItemId, StoreId, AisleId, Timestamp, AisleId, Timestamp, Timestamp, ItemId, StoreId, UserId],
                     DidUpdate).

item_removed_from_aisle(UserId, ItemId, StoreId, Timestamp, DidUpdate):-
        item_exists(UserId, ItemId, Timestamp, _),
        state_change('UPDATE aisle_item SET deleted = 1, last_updated = ? WHERE item_id = ? AND store_id = ? AND last_updated < ? AND user_id = ?',
                     [Timestamp, ItemId, StoreId, Timestamp, UserId],
                     DidUpdate).

sync_message(UserId, Timestamp, _{opcode:item_exists, item_id:ItemId}, MessageTimestamp):-
        select('SELECT item_id, last_updated FROM item WHERE last_updated > ? AND user_id = ?', [Timestamp, UserId], [ItemId, MessageTimestamp]).

sync_message(UserId, Timestamp, _{opcode:store_located_at, store_id:StoreId, latitude:Latitude, longitude:Longitude}, MessageTimestamp):-
        select('SELECT store_id, latitude, longitude, last_updated FROM store WHERE last_updated > ? AND user_id = ? AND latitude IS NOT NULL AND longitude IS NOT NULL', [Timestamp, UserId], [StoreId, Latitude, Longitude, MessageTimestamp]).


sync_message(UserId, Timestamp, _{opcode:store_exists, store_id:StoreId}, MessageTimestamp):-
        select('SELECT store_id, last_updated FROM store WHERE last_updated > ? AND user_id = ? AND latitude IS NULL AND longitude IS NULL', [Timestamp, UserId], [StoreId, MessageTimestamp]).

sync_message(UserId, Timestamp, _{opcode:Opcode, item_id:ItemId}, MessageTimestamp):-
        select('SELECT item_id, last_updated, deleted FROM list_entry WHERE last_updated > ? AND user_id = ?', [Timestamp, UserId], [ItemId, MessageTimestamp, Deleted]),
        ( Deleted == 0 ->
            Opcode = item_added_to_list
        ; otherwise->
            Opcode = item_deleted_from_list
        ).

sync_message(UserId, Timestamp, _{opcode:Opcode, item_id:ItemId, store_id:StoreId, aisle_id:AisleId}, MessageTimestamp):-
        select('SELECT item_id, store_id, aisle_id, last_updated, deleted FROM aisle_item WHERE last_updated > ? AND user_id = ?', [Timestamp, UserId], [ItemId, StoreId, AisleId, MessageTimestamp, Deleted]),
        ( Deleted == 0 ->
            Opcode = item_located_in_aisle
        ; otherwise->
            Opcode = item_removed_from_aisle
        ).

% This is very simple. If someone really wants to break into the server and steal the passwords, fine. If this were a public service they should be at least hashed
login(UserId, Password):-
        select('SELECT password FROM user WHERE user_id = ?', [UserId], [RequiredPassword]),
        Password == RequiredPassword.


import_from_old_database(FromFile):-
        prepare_database,
        format(atom(DriverString), 'DRIVER={Sqlite3};Database=~w;FKSupport=True;Read Only=True', [FromFile]),
        setup_call_cleanup(odbc_connect(-,
                                        SourceConnection,
                                        [driver_string(DriverString),
                                         silent(false),
                                         null({null}),
                                         auto_commit(true)]),
                           import_from_connection(SourceConnection),
                           odbc_disconnect(SourceConnection)).


import_from_connection(SourceConnection):-
        forall(odbc_query(SourceConnection, 'SELECT key, name FROM item', row(UserId, ItemId)),
               item_exists(UserId, ItemId, 1, _)),

        forall((odbc_query(SourceConnection, 'SELECT key, name, latitude, longitude FROM store', row(UserId, StoreId, Latitude, Longitude)),
                map_store(StoreId, MappedStoreId)),
               store_located_at(UserId, MappedStoreId, Latitude, Longitude, 1, _)),

        forall((odbc_query(SourceConnection, 'SELECT key, item, store, location FROM known_item_location', row(UserId, ItemId, StoreId, AisleId)),
                map_store(StoreId, MappedStoreId)),
               item_located_in_aisle(UserId, ItemId, MappedStoreId, AisleId, 1, _)),

        forall(odbc_query(SourceConnection, 'SELECT key, name FROM list_item', row(UserId, ItemId)),
               item_added_to_list(UserId, ItemId, 1, _)).


map_store(tesco, 'Tesco Cannonmills'):- !.
map_store(onion, _):- !, fail.
map_store(qfc, 'QFC Capitol Hill'):- !.
map_store(home, 'Home'):- !.
map_store('hing sing', 'Hing Sing'):- !.
map_store('tesco Leith', 'Tesco Leith'):- !.
map_store('tesco dundee', 'Tesco Riverside'):- !.
map_store('morrisons St. Andrews', 'Morrisons St. Andrews'):- !.
map_store('Matthew foods Dundee', 'Matthews Foods Dundee'):- !.
map_store(X, X).