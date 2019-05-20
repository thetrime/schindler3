var AppDispatcher = require('./AppDispatcher');
var assign = require('object-assign');
var EventEmitter = require('events').EventEmitter;

var status = "new";

var ServerConnectionStore = assign({},
                                   EventEmitter.prototype,
                                   {
                                       emitChange: function()
                                       {
                                           this.emit('change');
                                       },
                                       addChangeListener: function(callback)
                                       {
                                           this.on('change', callback);
                                       },
                                       removeChangeListener: function(callback)
                                       {
                                           this.removeListener('change', callback);
                                       },
                                       
                                       /* Actual logic */
                                       getConnectionStatus: function()
                                       {
                                           return status;
                                       }
                                       
                                   });

ServerConnectionStore.dispatchToken = AppDispatcher.register(function(event)
                                                             {
                                                                 if (event.operation == "connection")
                                                                 {
                                                                     status = event.data;
                                                                     ServerConnectionStore.emitChange();
                                                                 }
                                                             });

module.exports = ServerConnectionStore;
