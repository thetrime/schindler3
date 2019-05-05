:- use_module(library(http/websocket)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_files)).
:- use_module(library(http/json)).
:- use_module(library(http/http_session)).
:- use_module(library(http/http_ssl_plugin)).


:- http_handler(root(ws), http_upgrade_to_websocket(ws, []), [spawn([])]).
:- http_handler(root('.well-known'), acme, [prefix, priority(1)]).
:-initialization(start_server, program).

:-ensure_loaded(testing).
:-ensure_loaded(database).
:-ensure_loaded(tesco).

:-dynamic(listener/2).

acme(Request):-
        memberchk(path(Path), Request),
        format(atom(ActualPath), 'acme~w', [Path]),
        http_reply_file(ActualPath, [], Request).

ws(Websocket):-
        format(user_error, 'New connection received~n', []),
        set_stream(Websocket, encoding(utf8)),
        ws_receive(Websocket, Message, [format(json), value_string_as(atom)]),
        Message.opcode == text,
        UserId = Message.data.user_id,
        Password = Message.data.password,
        format(user_error, 'Login request for user ~w~n', [UserId]),
        ( login(UserId, Password)->
            format(user_error, 'Login successful for user ~w~n', [UserId]),
            setup_call_cleanup((thread_create(dispatch(Websocket), ClientId, [detached(true)]),
                                assert(listener(UserId, ClientId))
                               ),
                               client(ClientId, Websocket, UserId),
                               thread_send_message(ClientId, close))
        ; otherwise->
            ws_send(Websocket, text('{"opcode":"login_denied"}'))
        ).

client(ClientId, WebSocket, UserId) :-
        format(user_error, 'Waiting for message from user ~w (client ~w)~n', [UserId, ClientId]),
        ws_receive(WebSocket, Message, [format(json), value_string_as(atom)]),
        format(user_error, 'User ~w: Message: ~q~n', [UserId, Message]),
        ( Message.opcode == close ->
            thread_send_message(ClientId, close)
        ; Message.opcode == text ->
            Data = Message.data,
            Opcode = Data.opcode,
            ( catch(handle_message(Opcode, ClientId, UserId, Data),
                    Exception,
                    format(user_error, 'Exception while handling message with opcode ~w: ~p~n', [Opcode, Exception])),
                true
            ; otherwise->
                format(user_error, 'Failure handling message with opcode ~w~n', [Opcode])
            ),
            % If handled, send the message to all clients logged in as UserId who are not the current client
            send_message_to_other_clients(UserId, ClientId, Message.data),
            client(ClientId, WebSocket, UserId)
        ).

%%      send_message_to_other_clients(+UserId,
%%                                    +ClientId,
%%                                    +Message).
%       Send message Message to all clients logged in as UserId except the one called ClientId
send_message_to_other_clients(UserId, ClientId, Message):-
        with_output_to(atom(Atom),
                       json_write(current_output, Message, [null({null}), width(0)])),
        forall(listener(UserId, SomeClientId),
               ( SomeClientId \== ClientId ->
                   thread_send_message(SomeClientId, send(Atom))
               ; otherwise->
                   true
               )).



dispatch(WebSocket):-
        thread_get_message(Message),
        ( Message == close->
            !,
            thread_self(Self),
            retractall(listener(_, Self))
        ; Message = send(Atom)->
            ws_send(WebSocket, text(Atom)),
            format(user_error, 'Sent message ~w~n', [Atom]),
            dispatch(WebSocket)
        ; otherwise->
            format(user_error, 'Unexpected message ~q~n', [Message]),
            dispatch(WebSocket)
        ).


start_server:-
        prepare_database,
        prolog_server(9997, []),
        http_server(http_dispatch, [port(9007)]),
        % openssl req -nodes -subj '/CN=192.168.1.10' -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 3650
        http_server(http_dispatch, [port(9008), ssl([certificate_file('cert.pem'), key_file('key.pem')])]),
%        % ACME. Assumes port 80 is mapped to 8080 using something like "iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080"
        %        http_server(http_dispatch, [port(8080)]).
        true.

wait:-
        thread_get_message(_).



% The idea:
% First, timestamp all messages with a UTC timestamp
% Next, change the schema (on the server at least) so that items are never deleted from the list, but have is_present set to 0 or something.
% Also, add a last_updated column to every table.
% Then: Suppose we get a message from a client saying that item X is no longer on list Y, as of time T.
%       -> If the last_updated of current_item for item X, list Y is < T, then set is_present = 0 and last_updated to T
%       -> If the last_updated of current_item for item X, list Y is >= T then do nothing
% Then: Suppose we get a message from a client saying that item X is added to list Y, as of time T.
%       -> If there is no row for item X on list Y, insert it and set last_updated to T.
%       -> If the last_updated of current_item for item X, list Y is < T, then set is_present = 1 and last_updated to T
%       -> If the last_updated of current_item for item X, list Y is >= T then do nothing
% A sync message just needs to identify the last time we synced from the server. We can just get the state of everything where last_updated > sync_request_time and send it

% So, here are the messages we will receive from the clients:
%   * item_exists(item_id, timestamp)
%   * store_exists(store_id, timestamp)     (is this really useful?)
%   * store_located_at(store_id, latitude, longitude, timestamp)
%   * item_added_to_list(item_id, timestamp)
%   * item_deleted_from_list(item_id, timestamp)
%   * item_located_in_aisle(item_id, store_id, aisle_id, timestamp)
%   * item_removed_from_aisle(item_id, store_id, timestamp)
%   * sync(timestamp)
%   * login
% We will send back these messages:
%   * item_exists(item_id)
%   * store_exists(store_id)
%   * store_located_at(store_id, latitude, longitude)
%   * item_added_to_list(item_id)
%   * item_deleted_from_list(item_id)
%   * item_located_in_aisle(item_id, store_id, aisle_id)
%   * item_removed_from_aisle(item_id, store_id)

% The client is free to delete items from its database when the item is removed. The server must just mark the item as deleted but leave it in place. This is especially tricky for the item-location-in-store schema: We must make sure when we get the info from this table that we pick the (at most 1) row which is not deleted!

% The schema will be:
% item(item_id varchar, deleted boolean, last_updated timestamp)
% store(store_id varchar, latitude double, longitude double, deleted boolean, last_updated timestamp)
% aisle(item_id varchar, store_id varchar, aisle_id varchar, deleted boolean, last_updated timestamp)
% list_entry(item_id varchar, deleted boolean, last_updated timestamp)
% aisle_item(store_id varchar, aisle_id varchar, item_id varchar, deleted boolean, last_updated timestamp)

% TBD: We need a mechanism for sending these messages to any other people listening after we update the database without echoing them back to the originator

nuke(UserId):-
        with_output_to(atom(Atom),
                       json_write(current_output, _{opcode: nuke}, [null({null}), width(0)])),
        forall(listener(UserId, SomeClientId),
               thread_send_message(SomeClientId, send(Atom))).

message_chunk(Messages, Chunk, N, Id):-
        length(List, 20),
        ( append(List, Remainder, Messages)->
            ( ( Chunk = List, Id = N)
            ; ( NN is N+1, message_chunk(Remainder, Chunk, NN, Id)))
        ; otherwise->
            Chunk = Messages,
            Id = N
        ).

send_client_message(ClientId, MessageTerm):-
        with_output_to(atom(Atom), json_write(current_output, MessageTerm, [null({null}), width(0)])),
        thread_send_message(ClientId, send(Atom)).


handle_message(sync, ClientId, UserId, Data):-
        !,
        Timestamp = Data.timestamp,

        ( aggregate_all(r(bag(Message),
                          max(MessageTimestamp)),
                        sync_message(UserId, Timestamp, Message, MessageTimestamp),
                        r(Messages, MaxTimestamp))->
            send_client_message(ClientId, _{opcode:sync_start}),
            forall(message_chunk(Messages, Chunk, 0, Id),
                   send_client_message(ClientId, _{opcode:sync_message, messages:Chunk, chunk:Id})),
            send_client_message(ClientId, _{opcode:sync_complete, timestamp:MaxTimestamp})
        ; otherwise->
            % Nothing to do
            format(user_error, 'Nothing to sync for user ~w as client ~w', [UserId, ClientId])
        ).

handle_message(item_exists, _ClientId, UserId, Data):-
        !,
        ItemId = Data.item_id,
        Timestamp = Data.timestamp,
        item_exists(UserId, ItemId, Timestamp, _DidUpdate).


handle_message(store_exists, _ClientId, UserId, Data):-
        !,
        StoreId = Data.store_id,
        Timestamp = Data.timestamp,
        store_exists(UserId, StoreId, Timestamp, _DidUpdate).

handle_message(store_located_at, _ClientId,UserId, Data):-
        !,
        StoreId = Data.store_id,
        Latitude = Data.latitude,
        Longitude = Data.longitude,
        Timestamp = Data.timestamp,
        store_located_at(UserId, StoreId, Latitude, Longitude, Timestamp, _DidUpdate).

handle_message(item_added_to_list, _ClientId, UserId, Data):-
        !,
        ItemId = Data.item_id,
        Timestamp = Data.timestamp,
        item_added_to_list(UserId, ItemId, Timestamp, _DidUpdate).

handle_message(item_deleted_from_list, _ClientId, UserId, Data):-
        !,
        ItemId = Data.item_id,
        Timestamp = Data.timestamp,
        item_deleted_from_list(UserId, ItemId, Timestamp, _DidUpdate).

handle_message(item_located_in_aisle, _ClientId, UserId, Data):-
        !,
        ItemId = Data.item_id,
        StoreId = Data.store_id,
        AisleId = Data.aisle_id,
        Timestamp = Data.timestamp,
        item_located_in_aisle(UserId, ItemId, StoreId, AisleId, Timestamp, _DidUpdate).

handle_message(item_removed_from_aisle, _ClientId, UserId, Data):-
        !,
        ItemId = Data.item_id,
        StoreId = Data.store_id,
        Timestamp = Data.timestamp,
        item_removed_from_aisle(UserId, ItemId, StoreId, Timestamp, _DidUpdate).
