% This module comprises the Schindler2 HTTP client in case of emergency
% Basically it is a rewrite of the code to use the database primitives of Schindler3. The client itself does not require any changes
% To achieve this, the Schindler3 client (which connected to /ws) will instead have to connect to /ws3
% This is a backward-incompatible change breaking builds before 20 May 2019

:-module(schindler2, []).

:- http_handler(root(.), http_reply_from_files('schindler2', [indexes(['schindler.html'])]), [prefix]).
:- http_handler(root(ws), http_upgrade_to_websocket(ws2, []), [spawn([])]).


:-dynamic(listener/2).

ws2(Websocket):-
        set_stream(Websocket, encoding(utf8)),
        thread_create(dispatch2(Websocket), ClientId, [detached(true)]),
        client2(ClientId, Websocket, {null}).


client2(ClientId, WebSocket, Key) :-
        format(user_error, '(Legacy) Waiting for message...~n', []),
        ws_receive(WebSocket, Message, [format(json), value_string_as(atom)]),
        format(user_error, 'User ~w: Message: ~q~n', [Key, Message]),
        ( Message.opcode == close ->
            thread_send_message(ClientId, close)
        ; Message.opcode == text ->
            Data = Message.data,
            Operation = Data.operation,
            Fields = Data.data,
            ( Operation == login->
                % This is slightly different logic
                login(Fields, ClientId, Key, NewKey)
            ; otherwise->
                NewKey = Key,
                ( catch(handle_message(Key, Operation, Fields),
                        Exception,
                        format(user_error, 'Error: ~p~n', [Exception]))->
                    true
                ; otherwise->
                    format(user_error, 'Error: ~p~n', [fail])
                )
            ),
            client2(ClientId, WebSocket, NewKey)
        ; otherwise->
            client2(ClientId, WebSocket, Key)
        ).

ws_send_message(Key, Operation, Data):-
        with_output_to(atom(Atom),
                       json_write(current_output, _{operation:Operation, data:Data}, [null({null}), width(0)])),
        forall(listener(Key, ClientId),
               thread_send_message(ClientId, send(Atom))).

dispatch2(WebSocket):-
        thread_get_message(Message),
        ( Message == close->
            !,
            thread_self(Self),
            retractall(listener(_, Self))
        ; Message = send(Atom)->
            ws_send(WebSocket, text(Atom)),
            format(user_error, 'Sent message ~w~n', [Atom]),
            dispatch2(WebSocket)
        ; otherwise->
            format(user_error, 'Unexpected message ~q~n', [Message]),
            dispatch2(WebSocket)
        ).

%-------------------------------------

login(Fields, ClientId, Key, NewKey):-
        format(user_error, 'Fields: ~q~n', [Fields]),
        Username = Fields.username,
        Password = Fields.password,
        ( login(Username, Password)->
            NewKey = Username,
            retractall(listener(_, ClientId)),
            assert(listener(NewKey, ClientId)),
            ws_send_message(NewKey, login_ok, _{username:Username,
                                                  password:Password})
        ; otherwise->
            NewKey = Key,
            with_output_to(atom(Failed), json_write(current_output, _{operation:login_failed, data:{}}, [null({null})])),
            thread_send_message(ClientId, send(Failed))
        ).

get_timestamp(Timestamp):-
        get_time(TimestampBase),
        Timestamp is integer(TimestampBase * 1000).

handle_message({null}, hello, _):-
        !,
        ws_send_message({null}, ohai, _{stores:[],
                                        aisles:[],
                                        item_locations:[],
                                        items:[],
                                        list:[],
                                        checkpoint:{null}}).
handle_message(Key, hello, Message):-
        Checkpoint = Message.checkpoint,
        checkpoint(Key, NewCheckpoint),
        ( Checkpoint == NewCheckpoint ->
            ws_send_message(Key, ohai_again, _{})
        ; otherwise->
            location_information(Key, Locations),
            store_information(Key, Stores),
            item_information(Key, Items),
            aisle_information(Key, Aisles),
            list_information(Key, List),
            ws_send_message(Key, ohai, _{stores:Stores,
                                         aisles:Aisles,
                                         item_locations:Locations,
                                         items:Items,
                                         list:List,
                                         checkpoint:NewCheckpoint})
        ).

handle_message(Key, got_item, Message):-
        Name = Message.name,
        get_timestamp(Timestamp),
        item_deleted_from_list(Key, Name, Timestamp, _),
        ws_send_message(Key, delete_item, _{name:Name}).

handle_message(Key, new_item, Message):-
        Name = Message.name,
        get_timestamp(Timestamp),
        item_exists(Key, Name, Timestamp, _),
        item_added_to_list(Key, Name, Timestamp, _),
        ws_send_message(Key, add_list_item, _{name:Name}).


handle_message(Key, want_item, Message):-
        Name = Message.name,
        get_timestamp(Timestamp),
        item_added_to_list(Key, Name, Timestamp, _),
        ws_send_message(Key, add_list_item, _{name:Name}).

handle_message(Key, new_aisle, Message):-
        Name = Message.name,
        Store = Message.store,
        % This has no Schindler-3 equivalent.
        ws_send_message(Key, new_aisle, _{name:Name,
                                          store:Store}).

handle_message(Key, set_item_location, Message):-
        Item = Message.item,
        Location = Message.location,
        Store = Message.store,
        ( aisle(Key, Location, Store)->
            true
        ; otherwise->
            handle_message(Key, new_aisle, _{name:Location,
                                             store:Store})
        ),
        get_timestamp(Timestamp),
        item_located_in_aisle(Key, Item, Store, Location, Timestamp, _),
        ws_send_message(Key, set_item_location, Message).


handle_message(Key, new_store, Message):-
        Name = Message.name,
        Latitude = Message.latitude,
        Longitude = Message.longitude,
        get_timestamp(Timestamp),
        % CHECKME: Is Latitude/Longitude in the right format?
        store_located_at(Key, Name, Latitude, Longitude, Timestamp, _),
        ws_send_message(Key, new_store, Message).

handle_message(Key, delete_store, Message):-
        % This is not possible in Schindler-3 (yet)
        ws_send_message(Key, delete_store, Message).

handle_message(Key, set_store_location, Message):-
        Name = Message.name,
        Latitude = Message.latitude,
        Longitude = Message.longitude,
        get_timestamp(Timestamp),
        % CHECKME: Is Latitude/Longitude in the right format?
        store_located_at(Key, Name, Latitude, Longitude, Timestamp, _),
        ws_send_message(Key, set_store_location, Message).


item_information(Key, Items):-
        ( bagof(x{name:Name},
                item(Key, Name),
                Items)->
            true
        ; otherwise->
            Items = []
        ).

location_information(Key, Locations):-
        ( bagof(x{store_name:Store,
                  aisles:Aisles},
                bagof(y{aisle_name:Aisle,
                        items:Items},
                      bagof(Item,
                            item_location(Key, Item, Store, Aisle),
                            Items),
                      Aisles),
                Locations)
        ; otherwise->
            Locations = []
        ).


list_information(Key, Data):-
        ( bagof(x{name:Name},
                list_item(Key, Name),
                Data)->
            true
        ; otherwise->
            Data = []
        ).

store_information(Key, Data):-
        ( bagof(x{name:Name,
                  latitude:Latitude,
                  longitude:Longitude},
                store(Key, Name, Latitude, Longitude),
                Data)->
            true
        ; otherwise->
            Data = []
        ).

aisle_information(Key, Data):-
        ( bagof(x{name:Name,
                  store:Store},
                aisle(Key, Name, Store),
                Data)->
            true
        ; otherwise->
            Data = []
        ).

% These are all horrendeously inefficient but require no code changes to the existing schindler3 database code
aisle(UserId, AisleId, StoreId):-
        sync_message(UserId, 0, _{opcode:item_located_in_aisle, item_id:_, store_id:StoreId, aisle_id:AisleId}, _).

item_location(UserId, ItemId, StoreId, AisleId):-
        sync_message(UserId, 0, _{opcode:item_located_in_aisle, item_id:ItemId, store_id:StoreId, aisle_id:AisleId}, _).

store(UserId, StoreId, Latitude, Longitude):-
        sync_message(UserId, 0, _{opcode:store_located_at, store_id:StoreId, latitude:Latitude, longitude:Longitude}, _).

list_item(UserId, ItemId):-
        sync_message(UserId, 0, _{opcode:item_added_to_list, item_id:ItemId}, _).

item(UserId, ItemId):-
        sync_message(UserId, 0, _{opcode:item_exists, item_id:ItemId}, _).

checkpoint(UserId, Checkpoint):-
        % This seems extremely expensive
        aggregate_all(max(MessageTimestamp),
                      sync_message(UserId, _, _, MessageTimestamp),
                      Checkpoint).
