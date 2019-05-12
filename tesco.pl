:-encoding(utf8).

:-use_module(library(http/http_open)).
:-use_module(library(xpath)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_ssl_plugin)).
:- use_module(library(http/http_cookie)).
:- use_module(library(http/http_session)).

:-ensure_loaded(testing).
:-ensure_loaded(credentials).

:-http_handler(root(tesco), tesco, []).
:-http_handler(root('tesco.css'), http_reply_file('tesco.css', []), []).
:-http_handler(root(add_item), add_item, []).
:-http_handler(root(skip_item), skip_item, []).
:-http_handler(root(set_query), set_query, []).
:- use_module(library(http/http_client)).

:-initialization(start_tesco, program).

start_tesco:-
        message_queue_create(tesco_queue),
        forall(between(1, 10, _),
               thread_create(tesco_thread, _, [detached(true)])).

tesco_thread:-
        thread_get_message(tesco_queue, Task),
        ( catch(tesco_task(Task),
                Exception,
                format(user_error, 'Error processing tesco task: ~w~n', [Exception]))->
            true
        ; format(user_error, 'Failure processing tesco task~n', [])
        ),
        tesco_thread.

tesco_task(refresh_cache(UserId, SessionId, ItemId, ThreadId)):-
        refresh_tesco_cache(UserId, SessionId, ItemId, _Products),
        thread_send_message(ThreadId, cached).

refresh_tesco_cache(UserId, SessionId, ItemId, Products):-
        delete_tesco_cache(UserId, ItemId),
        ( item_query_string(UserId, ItemId, QueryString)->
            true
        ; otherwise->
            QueryString = ItemId
        ),
        tesco_products(UserId, QueryString, SessionId, Products),
        forall(member(product(IsFavourite, ProductTitle, ProductId, Image, Price, Offer, CSRF), Products),
               cache_tesco_product(UserId, ItemId, ProductId, IsFavourite, ProductTitle, Image, Price, Offer, CSRF)).

:-dynamic(need_item/2).

item_favourite(UserId, ItemId, ProductId):-
        tesco_favourite(UserId, ItemId, ProductId).
remove_item_from_list(UserId, ItemId):-
        get_time(TimestampBase),
        Timestamp is integer(TimestampBase * 1000),
        item_deleted_from_list(UserId, ItemId, Timestamp, _).
unfavourite_item(UserId, ItemId, ProductId):-
        delete_tesco_favourite(UserId, ItemId, ProductId).
set_favourite(UserId, ItemId, ProductId):-
        set_tesco_favourite(UserId, ItemId, ProductId).

item_query_string(UserId, ItemId, QueryString):-
        tesco_query_string(UserId, ItemId, QueryString).
set_query_string(UserId, ItemId, QueryString):-
        set_tesco_query_string(UserId, ItemId, QueryString).

% Begin actual code
generate_session(Request):-
        ( memberchk(method(get), Request)->
            memberchk(search(Search), Request),
            memberchk(user_id=UserId, Search),
            memberchk(password=Password, Search)
        ; otherwise->
            http_read_data(Request, Data, []),
            memberchk('user_id'=UserId, Data),
            memberchk('password'=Password, Data)
        ),
        ( login(UserId, Password)->
            true
        ; otherwise->
            throw(error(bad_credentials, _))
        ),
        http_session_assert(user_id(UserId)).



set_query(Request):-
        http_read_data(Request, Data, []),
        http_session_data(user_id(UserId)),
        memberchk('schindler_id'=ItemId, Data),
        memberchk('query'=Query, Data),
        set_query_string(UserId, ItemId, Query),
        generate_next_page('Ok. Did that help?', recache).

queue_item(UserId, ItemId):-
        ( need_item(UserId, ItemId)->
            true
        ; otherwise->
            assertz(need_item(UserId, ItemId)),
            thread_self(Self),
            http_session_id(SessionId),
            thread_send_message(tesco_queue, refresh_cache(UserId, SessionId, ItemId, Self))
        ).

skip_item(Request):-
        http_read_data(Request, Data, []),
        http_session_data(user_id(UserId)),
        memberchk('schindler_id'=ItemId, Data),
        retract(need_item(UserId, ItemId)),
        generate_next_page('No problem. Item has been left in your list', use_cache).

add_item(Request):-
        http_read_data(Request, Data, []),
        memberchk('_csrf'=CSRF, Data),
        memberchk('id'=ProductId, Data),
        memberchk('schindler_id'=ItemId, Data),
        memberchk('newValue'=NewValue, Data),
        http_session_data(user_id(UserId)),
        ( memberchk('unfavourite'=_, Data)->
            unfavourite_item(UserId, ItemId, ProductId),
            NextHeading = 'Ok, that item has been removed'
        ; otherwise->
            retract(need_item(UserId, ItemId)),
            http_session_id(SessionId),
            format(atom(URL), 'https://www.tesco.com/groceries/en-GB/trolley/items/~w?_method=PUT', [ProductId]),
            setup_call_cleanup(http_open(URL, Stream, [cacert_file(system(root_certificates)),
                                                       status_code(StatusCode),
                                                       %final_url(Final),
                                                       post(form([id=ProductId,
                                                                  anchorId = '',
                                                                  returnUrl = '',
                                                                  backToUrl = '#',
                                                                  oldValue = '0',
                                                                  oldUnitChoice = 'pcs',
                                                                  catchWeight = '',
                                                                  newUnitChoice = 'pcs',
                                                                  newValue=NewValue,
                                                                  '_csrf'=CSRF])),
                                                       request_header(origin='https://www.tesco.com'),
                                                       client(SessionId)]),
                               ( StatusCode == 200 ->
                                   true
                               ; copy_stream_data(Stream, user_error)
                               ),
                               close(Stream)),
            set_favourite(UserId, ItemId, ProductId),
            ( StatusCode == 200 ->
                remove_item_from_list(UserId, ItemId),
                format(atom(NextHeading), 'Success! ~w removed from list', [ItemId])
            ; otherwise->
                % Something went wrong
                format(atom(NextHeading), 'Hmm. There was a problem. ~w has been left on your list', [ItemId])
            )
        ),
        generate_next_page(NextHeading, use_cache).

tesco(Request):-
        generate_session(Request),
        http_session_data(user_id(UserId)),
        retractall(need_item(UserId, _)),
        findall(ItemId,
                current_list_item(UserId, ItemId),
                List),

        % First make sure we are logged in
        http_session_id(SessionId),
        tesco_login(UserId, SessionId),

        forall(member(ItemId, List),
               queue_item(UserId, ItemId)),

        % Then wait for all the items to be cached before proceeding
        forall(member(_ItemId, List),
               thread_get_message(cached)),
        generate_next_page('Hello, it\'s Tesco!', use_cache).

generate_next_page(Heading, WithCache):-
        http_session_data(user_id(UserId)),
        http_session_id(SessionId),
        ( need_item(UserId, ItemId)->
            ( fail, WithCache == use_cache ->
                cached_tesco_products(UserId, ItemId, Products)
            ; otherwise->
                refresh_tesco_cache(UserId, SessionId, ItemId, Products)
            ),
            findall(FavouriteId,
                    item_favourite(UserId, ItemId, FavouriteId),
                    FavouriteIds),
            generate_selection_page(Heading, ItemId, FavouriteIds, Products)
        ; otherwise->
            % Finished!
            format(current_output, 'Content-type: text/html~n~n<html><head><script>window.onload = function() {window.webkit.messageHandlers.callbackHandler.postMessage(\"Done\");}</script></head><body></body></html>', [])
        ).


tesco_products(_UserId, QueryString, SessionId, Products):-
        % This is done once when we start the process
        %tesco_login(UserId, SessionId),
        setup_call_cleanup(http_open([protocol(https), host('www.tesco.com'), path('/groceries/en-GB/search'), search([query=QueryString, count=100])], Stream, [cacert_file(system(root_certificates)), client(SessionId)]),
                           tesco_extract_products(Stream, Products),
                           close(Stream)).

tesco_login(UserId, SessionId):-
        ( tesco_tokens(SessionId, State, CSRF) ->
            % Need to log in
            tesco_credentials(UserId, Username, Password),
            setup_call_cleanup(http_open('https://secure.tesco.com/account/en-GB/login', Stream, [cacert_file(system(root_certificates)),
                                                                                                    post(form([username=Username, password=Password, state=State, '_csrf'=CSRF])),
                                                                                                    client(SessionId)]),
                               true,
                               close(Stream))
        ; otherwise->
            % Maybe already logged in?
            true
        ).

cache_html(HTML, Stub):-
        format(atom(Filename), '/tmp/cached_~w.html', [Stub]),
        setup_call_cleanup(open(Filename, write, Stream),
                           html_write(Stream, HTML, []),
                           close(Stream)).

tesco_tokens(SessionId, State, CSRF):-
        setup_call_cleanup(http_open('https://secure.tesco.com/account/en-GB/login', Stream, [cacert_file(system(root_certificates)), client(SessionId)]),
                           load_html(Stream, HTML, []),
                           close(Stream)),
        %cache_html(HTML, token),
        xpath(HTML, //input(@id='state'), element(_, StateAttributes, _)),
        xpath(HTML, //input(@id='_csrf'), element(_, CSRFAttributes, _)),
        memberchk(value=State, StateAttributes),
        memberchk(value=CSRF, CSRFAttributes),
        !.

tesco_extract_products(Stream, Products):-
        load_html(stream(Stream), HTML, []),
        cache_html(HTML, products),
        findall(product(IsFavourite, ProductTitle, ProductId, Image, Price, Offer, CSRF),
                tesco_product(HTML, ProductTitle, ProductId, Image, IsFavourite, Price, Offer, CSRF),
                Products).

generate_selection_page(Banner, ItemId, FavouriteIds, Products):-
        ( FavouriteIds == [] ->
            FavouriteProducts = [],
            FavouriteSection = element(div, [], ['You have never bought ', ItemId, ' before']),
            NonFavouriteProducts = Products
        ; otherwise->
            select_favourite_products(Products, FavouriteIds, FavouriteProducts, NonFavouriteProducts),
            ( FavouriteProducts == [] ->
                FavouriteSection = element(div, [], ['While you have bought ', ItemId, ' before, none of the products you bought last time exist anymore :('])
            ; FavouriteProducts = [_]->
                FavouriteSection = element(div, [], [element(span, [], ['Usually when you buy ', ItemId, ', you want this:']),
                                                     element(div, [class=favourite_items], FavouriteItems)]),
                findall(Element,
                        element_in_products(ItemId, FavouriteProducts, true, Element),
                        FavouriteItems)
            ; otherwise->
                FavouriteSection = element(div, [], [element(span, [], ['Usually when you buy ', ItemId, ', you want one of these:']),
                                                     element(div, [class=favourite_items], FavouriteItems)]),
                findall(Element,
                        element_in_products(ItemId, FavouriteProducts, true, Element),
                        FavouriteItems)
            )
        ),
        findall(Element,
                element_in_products(ItemId, NonFavouriteProducts, false, Element),
                Items),
        format(current_output, 'Content-type: text/html~n~n', []),
        ( FavouriteProducts == [] ->
            OtherSection = element(div, [class=other_items], Items)
        ; otherwise->
            OtherSection = element(div, [], ['But maybe you want one of these?', element(div, [class=other_items], Items)])
        ),
        html_write(current_output, [element(html, [], [element(head, [], [element(link, [rel=stylesheet, type='text/css', href='tesco.css'], []),
                                                                          element(meta, [name=viewport, content='width=device-width, initial-scale=1.0'], [])]),
                                                       element(body, [], [element(h2, [], [Banner]),
                                                                          element(h3, [], ['You are trying to add ', ItemId, ' to your Tesco basket. Please pick from the following options:']),
                                                                          element(form, [action='/skip_item', method=post], [element(input, [type=hidden, name=schindler_id, value=ItemId], []),
                                                                                                                             element(button, [], ['Skip adding ', ItemId, ' to this shop and leave it in Schindler'])]),
                                                                          FavouriteSection,
                                                                          element(form, [action='/set_query', method=post], [element(input, [type=hidden, name=schindler_id, value=ItemId], []),
                                                                                                                             element(input, [class=query, name=query], []),
                                                                                                                             element(button, [], ['When looking for ', ItemId, ', search for this instead'])]),
                                                                          element(hr, [], []),
                                                                          OtherSection])])], []).


product_id(product(_IsFavourite, _ProductTitle, ProductId, _Image, _Price, _Offer, _CSRF), ProductId).

select_favourite_products([], _, [], []):- !.
select_favourite_products([Product|Products], FavouriteIds, [Product|FavouriteProducts], NonFavouriteProducts):-
        product_id(Product, ProductId),
        memberchk(ProductId, FavouriteIds),
        !,
        select_favourite_products(Products, FavouriteIds, FavouriteProducts, NonFavouriteProducts).
select_favourite_products([Product|Products], FavouriteIds, FavouriteProducts, [Product|NonFavouriteProducts]):-
        select_favourite_products(Products, FavouriteIds, FavouriteProducts, NonFavouriteProducts).

element_in_products(ItemId, Products, CanUnfavourite, Element):-
        member(product(_IsFavourite, ProductTitle, ProductId, Image, Price, Offer, CSRF), Products),
        ( Offer == '' ->
            OfferSpan = element(span, [], [])
        ; otherwise->
            OfferSpan = element(span, [class=offer], [' (', Offer, ')'])
        ),
        Element = element(div, [class=product], [element(img, [src=Image], []),
                                                 ProductTitle,
                                                 element(div, [class=price], ['  £', Price]),
                                                 OfferSpan,
                                                 element(form, [action='/add_item', method='POST'], [element(input, [value='', type=text, pattern='\\d*', name=newValue], []),
                                                                                                     element(input, [type=hidden, name='id', value=ProductId], []),
                                                                                                     element(input, [type=hidden, name='_csrf', value=CSRF], []),
                                                                                                     element(input, [type=hidden, name='schindler_id', value=ItemId], []),
                                                                                                     element(button, [type=submit, name=add], ['Add'])|Tail])]),
        ( CanUnfavourite == true ->
            Tail = [element(button, [type=submit, name=unfavourite], ['I don\'t like this product anymore'])]
        ; otherwise->
            Tail = []
        ).


tesco_product(HTML, ProductTitle, ProductId, Image, IsFavourite, Price, Offer, CSRF):-
        xpath(HTML, //div(@'data-auto'='product-tile'), Element),
        ( xpath(Element, //a(@class='product-tile--title product-tile--browsable'), element(a, _, [ProductTitle]))->
            true
        ; otherwise->
            format(user_error, 'No product title?~n', []),
            fail
        ),
        xpath(Element, //div(@class='product-image__container')/img, element(img, ImageAttributes, _)),
        memberchk(src=Image, ImageAttributes),
        xpath(Element, //form/input(@name=id), element(input, InputAttributes, _)),
        memberchk(value=ProductId, InputAttributes),
        ( xpath(Element, /span(@class='favourite-heart-icon'), _)->
            IsFavourite = favourite
        ; IsFavourite = not_favourite
        ),
        xpath(Element, //div(@class='price-per-sellable-unit price-per-sellable-unit--price price-per-sellable-unit--price-per-item')//span(@class=value), element(span, _, [Price])),
        ( xpath(Element, //span(@class='offer-text'), element(span, _, [Offer]))->
            true
        ; Offer = ''
        ),
        xpath(Element, //input(@name='_csrf'), element(_, CSRFAttributes, _)),
        memberchk(value=CSRF, CSRFAttributes).

% Also there is a JSON interface...
%{"items":[{"id":"253556398","newValue":1,"oldValue":0,"newUnitChoice":"pcs","oldUnitChoice":"pcs"}],"returnUrl":"/groceries/en-GB/search?query=lemons&icid=tescohp_sws-1_m-ft_in-lemons_ab-226-b_out-lemons"}