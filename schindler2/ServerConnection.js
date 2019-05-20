var AppDispatcher = require('./AppDispatcher');

module.exports =
    {
        queued_messages: [],
        websocket: null,
        handle_server_connect: function()
        {
            var credentials = JSON.parse(localStorage.getItem("credentials"));
            if (credentials !== null && credentials !== undefined && credentials.password !== null && credentials.password !== undefined)
            {
                this.sendMessage({operation:"login",
                                  data:credentials});
            }
            else
            {
                this.reloadList();
            }
            this.dispatchEvent("connection", "connected");
            this.dispatchQueuedMessages();
        },
        handle_server_disconnect: function()
        {
            console.log("Close detected. Reopening connection in 3 seconds...");
            this.dispatchEvent("connection", "disconnected");
            var that = this;
            setTimeout(function() {that.reconnect();}, 3000);
        },

        reconnect: function()
        {
            var new_websocket = new WebSocket(this.uri);
            new_websocket.onmessage = this.websocket.onmessage;
            new_websocket.onopen = this.websocket.onopen;
            new_websocket.onclose = this.websocket.onclose;
            new_websocket.onerror = this.websocket.onerror;
            this.websocket = new_websocket;
        },

        dispatchQueuedMessages: function()
        {
            var copy = this.queued_messages;
            this.queued_messages = [];
            localStorage.setItem("pending_messages", JSON.stringify(this.queued_messages));
            copy.forEach(function(message) {this.sendMessage(message);}.bind(this));
        },
        
        dispatchEvent: function(key, data)
        {
            AppDispatcher.dispatch({operation:key,
                                    data:data});
        },
        sendMessage: function(message)
        {
            if (this.websocket.readyState == this.websocket.OPEN)
            {
                this.websocket.send(JSON.stringify(message));
            }
            else
            {
                this.queued_messages.push(message);
                localStorage.setItem("pending_messages", JSON.stringify(this.queued_messages));
            }
        },
        handle_server_message: function(event)
        {
            var msg = JSON.parse(event.data);
            this.dispatchEvent(msg.operation, msg.data);
        },
        
        reloadList: function()
        {
            var checkpoint = localStorage.getItem("checkpoint");
            this.sendMessage({operation:"hello", data:{version:1,
                                                       checkpoint:checkpoint}});
        },
        
        initialize: function()
        {
            var loc = window.location;
            this.queued_messages = JSON.parse(localStorage.getItem("pending_messages"));
            this.uri = "ws:";
            if (loc.protocol === "https:") 
                this.uri = "wss:";
            this.uri += "//" + loc.host;
            this.uri += loc.pathname + "ws";
            this.websocket = new WebSocket(this.uri);
            this.websocket.onmessage = this.handle_server_message.bind(this);
            this.websocket.onclose = this.handle_server_disconnect.bind(this);
            this.websocket.onopen = this.handle_server_connect.bind(this);
        }
    };
