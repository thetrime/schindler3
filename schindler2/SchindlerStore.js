var AppDispatcher = require('./AppDispatcher');
var assign = require('object-assign');
var EventEmitter = require('events').EventEmitter;
var ServerConnection = require('./ServerConnection');
var StoreStore = require('./StoreStore');

var current_view = localStorage.getItem("credentials") == null?"login":"shop";
var pending_item = {};
var managing_store = {};

var SchindlerStore = assign({},
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
                                getTopLevelView: function()
                                {
                                    return current_view;
                                },
                                getPendingItem: function()
                                {
                                    return pending_item;
                                },
                                getManagingStore: function()
                                {
                                    return managing_store;
                                }
                                
                            });

SchindlerStore.dispatchToken = AppDispatcher.register(function(event)
                                                      {
                                                          if (event.operation == "got_item")
                                                          {
                                                              if (event.data.location == null)
                                                              {
                                                                  // The user is insistent that they do not care - just delete the thing!
                                                                  current_view = "shop";
                                                                  pending_item = {};
                                                              }
                                                              else if (StoreStore.getCurrentStore() == undefined)
                                                              {
                                                                  current_view = "select_store";
                                                                  pending_item = event.data;
                                                              }
                                                              else if (event.data.location == "unknown")
                                                              {
                                                                  current_view = "select_aisle";
                                                                  pending_item = event.data;
                                                              }                              
                                                              else
                                                              {
                                                                  current_view = "shop";
                                                                  pending_item = {};
                                                              }
                                                              SchindlerStore.emitChange();
                                                          }
                                                          if (event.operation == "login_ok")
                                                          {
                                                              localStorage.setItem("credentials", JSON.stringify({username:event.data.username,
                                                                                                                  password:event.data.password}));
                                                              SchindlerStore.emitChange();
                                                              (ServerConnection.reloadList.bind(ServerConnection))()
                                                          }
                                                          if (event.operation == "login_ok" && current_view == "login")
                                                          {
                                                              AppDispatcher.waitFor([StoreStore.dispatchToken]);
                                                              current_view = "shop";
                                                              SchindlerStore.emitChange();
                                                          }
                                                          if (event.operation == "login_failed")
                                                          {
                                                              // FIXME: Do /something/! This should probably be listened to by the LoginView
                                                          }
                                                          if (event.operation == "select_store")
                                                          {
                                                              current_view = "select_store";
                                                              SchindlerStore.emitChange();
                                                          }
                                                          if (event.operation == "logout")
                                                          {
                                                              localStorage.removeItem("credentials");
                                                              current_view = "login";
                                                              SchindlerStore.emitChange();
                                                          }
                                                          if (event.operation == "set_store")
                                                          {
                                                              // Wait for the store to be changed before we swap the view back
                                                              AppDispatcher.waitFor([StoreStore.dispatchToken]);
                                                              current_view = "shop";
                                                              SchindlerStore.emitChange();
                                                          }
                                                          if (event.operation == "manage_store")
                                                          {
                                                              current_view = "manage_store";
                                                              managing_store = event.data.store;
                                                              SchindlerStore.emitChange();
                                                          }
                                                          if (event.operation == "manage_store_complete")
                                                          {
                                                              current_view = "shop";
                                                              managing_store = {};
                                                              SchindlerStore.emitChange();
                                                          }

                                                      });

module.exports = SchindlerStore;
