:-module(database,
         [item_exists/4,
          store_exists/4,
          store_located_at/6,
          aisle_exists_in_store/5,
          item_added_to_list/4,
          item_deleted_from_list/4,
          item_located_in_aisle/6,
          item_removed_from_aisle/5,
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
        ignore(odbc_query(Connection, 'CREATE TABLE item(user_id VARCHAR, item_id VARCHAR, deleted INTEGER, last_updated INTEGER, PRIMARY KEY(user_id, item_id))', _)),
        ignore(odbc_query(Connection, 'CREATE TABLE list_entry(user_id VARCHAR, item_id VARCHAR, deleted INTEGER, last_updated INTEGER, PRIMARY KEY(user_id, item_id), FOREIGN KEY(user_id, item_id) REFERENCES item(user_id, item_id))', _)),
        ignore(odbc_query(Connection, 'CREATE TABLE store(user_id VARCHAR, store_id VARCHAR, latitude VARCHAR, longitude VARCHAR, deleted INTEGER, last_updated INTEGER, PRIMARY KEY(user_id, store_id))', _)),
        ignore(odbc_query(Connection, 'CREATE TABLE aisle(user_id VARCHAR, store_id VARCHAR, aisle_id VARCHAR, deleted INTEGER, last_updated INTEGER, PRIMARY KEY(user_id, store_id, aisle_id), FOREIGN KEY(user_id, store_id) REFERENCES store(user_id, store_id))', _)),
        ignore(odbc_query(Connection, 'CREATE TABLE aisle_item(user_id VARCHAR, item_id VARCHAR, store_id VARCHAR, aisle_id VARCHAR, deleted INTEGER, last_updated INTEGER, FOREIGN KEY(user_id, item_id) REFERENCES item(user_id, item_id), FOREIGN KEY(user_id, store_id) REFERENCES store(user_id, store_id), FOREIGN KEY(user_id, store_id, aisle_id) REFERENCES aisle(user_id, store_id, aisle_id))', _)).


state_change(SQL, Parameters, DidUpdate):-
        get_connection(Connection),
        findall(default, member(_, Parameters), Defaults),
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

item_exists(UserId, ItemId, Timestamp, DidUpdate):-
        % INSERT INTO item(item_id, deleted, last_updated) VALUES (?ItemId, 0, ?Timestamp) ON CONFLICT UPDATE item SET deleted = 0, last_updated = ?Timestamp WHERE last_updated < ?Timestamp AND item_id = ?ItemId
        state_change('INSERT INTO item(user_id, item_id, deleted, last_updated) VALUES (?, ?, 0, ?) ON CONFLICT(user_id, item_id) DO UPDATE SET deleted = 0, last_updated = ? WHERE last_updated < ? AND item_id = ? AND user_id = ?', [UserId, ItemId, Timestamp, Timestamp, Timestamp, ItemId, UserId], DidUpdate).


store_exists(UserId, StoreId, Timestamp, DidUpdate):-
        % INSERT INTO store(store_id, deleted, last_updated) VALUES (?StoreId, 0, ?Timestamp) ON CONFLICT UPDATE store SET deleted = 0, last_updated = ?Timestamp WHERE last_updated < ?Timestamp AND store_id = ?StoreId
        state_change('INSERT INTO store(user_id, store_id, deleted, last_updated) VALUES (?, ?, 0, ?) ON CONFLICT(user_id, store_id) DO UPDATE SET deleted = 0, last_updated = ? WHERE last_updated < ? AND store_id = ? AND user_id = ?', [UserId, StoreId, Timestamp, Timestamp, Timestamp, StoreId, UserId], DidUpdate).

store_located_at(UserId, StoreId, Latitude, Longitude, Timestamp, DidUpdate):-
        % INSERT INTO store(store_id, latitude, longitude, deleted, last_updated) VALUES (?StoreId, ?Latitude, ?Longitude, 0, ?Timestamp) ON CONFLICT UPDATE store SET latitude = ?Latitude, longitude = ?Longitude, deleted = 0, last_updated = ?Timestamp WHERE last_updated < ?Timestamp AND store_id = ?StoreId
        state_change('INSERT INTO store(user_id, store_id, latitude, longitude, deleted, last_updated) VALUES (?, ?, ?, ?, 0, ?) ON CONFLICT(user_id, store_id) DO UPDATE SET latitude = ?, longitude = ?, deleted = 0, last_updated = ? WHERE last_updated < ? AND store_id = ? AND user_id = ?',
                     [UserId, StoreId, Latitude, Longitude, Timestamp, Latitude, Longitude, Timestamp, Timestamp, StoreId, UserId],
                     DidUpdate).

aisle_exists_in_store(UserId, StoreId, AisleId, Timestamp, DidUpdate):-
        % INSERT INTO aisle(store_id, aisle_id, deleted, last_updated) VALUES (?StoreId, ?AisleId, 0, ?Timestamp) ON CONFLICT UPDATE aisle SET deleted = 0, last_updated = ?Timestamp WHERE last_updated < ?Timestamp AND store_id = ?StoreId AND aisle_id = ?AisleID
        state_change('INSERT INTO aisle(user_id, store_id, aisle_id, deleted, last_updated) VALUES (?, ?, ?, 0, ?) ON CONFLICT(user_id, store_id, aisle_id) DO UPDATE SET deleted = 0, last_updated = ? WHERE last_updated < ? AND store_id = ? AND aisle_id = ? and user_id = ?',
                     [UserId, StoreId, AisleId, Timestamp, Timestamp, Timestamp, StoreId, AisleId, UserId],
                     DidUpdate).

item_added_to_list(UserId, ItemId, Timestamp, DidUpdate):-
        state_change('INSERT INTO list_entry(user_id, item_id, deleted, last_updated) VALUES (?, ?, 0, ?) ON CONFLICT(user_id, item_id) DO UPDATE SET deleted = 0, last_updated = ? WHERE last_updated < ? AND item_id = ? AND user_id = ?',
                     [UserId, ItemId, Timestamp, Timestamp, Timestamp, ItemId, UserId],
                     DidUpdate).

item_deleted_from_list(UserId, ItemId, Timestamp, DidUpdate):-
        state_change('UPDATE list_entry SET deleted = 0, last_updated = ? WHERE item_id = ? AND last_updated < ? AND user_id = ?',
                     [Timestamp, ItemId, Timestamp, UserId],
                     DidUpdate).

item_located_in_aisle(UserId, ItemId, StoreId, AisleId, Timestamp, DidUpdate):-
        state_change('INSERT INTO aisle_item(user_id, item_id, store_id, aisle_id, deleted, last_updated) VALUES (?, ?, ?, ?, 0, ?) ON CONFLICT(user_id, item_id, store_id) DO UPDATE SET aisle_id = ?, deleted = 0, last_updated = ? WHERE last_updated < ? AND item_id = ? AND store_id = ? AND user_id = ?',
                     [UserId, ItemId, StoreId, AisleId, Timestamp, AisleId, Timestamp, Timestamp, ItemId, StoreId, UserId],
                     DidUpdate).

item_removed_from_aisle(UserId, ItemId, StoreId, Timestamp, DidUpdate):-
        state_change('UPDATE aisle_item SET deleted = 1, last_updated = ? WHERE item_id = ? AND store_id = ? AND last_updated < ? AND user_id = ?',
                     [Timestamp, ItemId, StoreId, Timestamp, UserId],
                     DidUpdate).