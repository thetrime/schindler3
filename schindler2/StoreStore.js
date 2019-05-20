var AppDispatcher = require('./AppDispatcher');
var assign = require('object-assign');
var EventEmitter = require('events').EventEmitter;
var ServerConnection = require('./ServerConnection');
var GPSTracker = require('./GPSTracker');
var stores = {};
var all_items = [];
var current_list = [];
var current_store = undefined;
var deferred_items = [];

function setCurrentList(i)
{
    current_list = [];
    i.forEach(function(item)              
              {
                  addItemToCurrentList(item);
              });
}

function addItemToCurrentList(item)
{
    var new_item = {name:item.name,
                    on_list:true,
                    location:StoreStore.getAisleFor(item.name)};
    current_list.push(new_item);
}

function relocateItems()
{
    var i = current_list;
    current_list = [];
    i.forEach(function(item)
              {
                  addItemToCurrentList(item);
              });
}

function restoreDeferredItems()
{
    deferred_items.forEach(function(item)
                           {
                               addItemToCurrentList({name:item});
                           });
    deferred_items = [];
    localStorage.setItem("deferred_items", JSON.stringify([]));

}

function getNearestStoreTo(position)
{
    var distance = -1;
    var store;
    console.log("Getting nearest store from ");
    console.log(stores);
    Object.keys(stores).forEach(function(storeName)
                                {
                                    var d = GPSTracker.haversine(stores[storeName].location, position);
                                    console.log('Distance to ' + storeName + ' is ' + d + ' metres');
				    if (d < 500 && (distance == -1 || d < distance))
                                    //if (distance == -1 || d < distance)
                                    {
                                        distance = d;
                                        store = storeName;
                                    }
                                });
    console.log('The closest store is ' + store);
    return store;
}

function ensureAisleExists(store, aisle)
{
    var found = false;
    for (var i = 0; i < stores[store].aisles.length; i++)
    {
        if (stores[store].aisles[i].name == aisle)
        {
            found = true;
            break;
        }
    }
    if (!found)
        stores[store].aisles.push({name:aisle,
                                   index:-1});
}

var StoreStore = assign({},
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
                            getCurrentList: function()
                            {
                                return current_list;
                            },
                            
                            getStoreNames: function()
                            {
                                var store_names = [];
                                Object.keys(stores).forEach(function(s) { store_names.push({name: s});});
                                return store_names;
                            },

                            // getCurrentStore returns undefined if we are not at any known store
                            getCurrentStore: function()
                            {
                                return current_store;
                            },

                            getAisleFor: function(item)
                            {
                                if (current_store == undefined || stores[current_store].item_locations[item] === undefined)
                                    return "unknown";
                                else
                                    return stores[current_store].item_locations[item];
                            },

                            getIndexOfAisle: function(aisleName)
                            {
                                stores[current_store].aisles.forEach(function(aisle)
                                                                     {
                                                                         if (aisle.name == aisleName)
                                                                             return aisle.index;
                                                                     });
                                return -1;
                            },

                            getAislesForCurrentStore: function()
                            {
                                var aisles = [];
                                if (current_store == undefined)
                                    return [];
                                console.log('Getting aisles');
                                console.log(stores[current_store].aisles);
                                stores[current_store].aisles.forEach(function(aisle)
                                                                     {
                                                                         aisles.push({name:aisle.name,
                                                                                      index:aisle.index});
                                                                     });
                                return aisles;
                            },
                            
                            getAislesForStore: function(store)
                            {
                                var aisles = [];
                                console.log(stores[store].aisles);
                                stores[store].aisles.forEach(function(aisle)
                                                             {
                                                                 aisles.push({name:aisle.name,
                                                                              index:aisle.index});
                                                             });
                                return aisles;
                            },                            

                            getItemsForCurrentStore: function()
                            {
                                var located_items = [];
                                all_items.forEach(function(item)
                                                  {
                                                      if (current_store == undefined || stores[current_store].item_locations[item.name] === undefined)
                                                          located_items.push({name:item.name,
                                                                              location:"unknown"});
                                                      else
                                                          located_items.push({name:item.name,
                                                                              location:stores[current_store].item_locations[item.name]});                                                  
                                              });
                               
                                return located_items;
                            }
                        });

StoreStore.dispatchToken = AppDispatcher.register(function(event)
                                                  {
                                                      if (event.operation == "ohai" || event.operation == "ohai_again")
                                                      {
                                                          if (event.operation == "ohai_again")
                                                          {
                                                              event.data = JSON.parse(localStorage.getItem("checkpoint_data"));
                                                          }
                                                          else
                                                          {
                                                              localStorage.setItem("checkpoint", event.data.checkpoint);
                                                              localStorage.setItem("checkpoint_data", JSON.stringify(event.data));
                                                          }
                                                          if (localStorage.getItem("deferred_items") == undefined)
                                                              deferred_items = [];
                                                          else
                                                              deferred_items = JSON.parse(localStorage.getItem("deferred_items"));
                                                          stores = {home:{location: {latitude:0,
                                                                                     longitude:0},
                                                                          aisles: [],
                                                                          item_locations: {}}};
                                                          console.log(event.data.stores);
                                                          // First construct the stores. Each store starts out with an empty aisle list and no item locations
                                                          event.data.stores.forEach(function(store)
                                                                                    {
                                                                                        stores[store.name] = {};
                                                                                        stores[store.name].location = {latitude:store.latitude,
                                                                                                                       longitude:store.longitude};
                                                                                        stores[store.name].aisles = [];
                                                                                        stores[store.name].item_locations = {};
                                                                                    });
                                                          // Just copy the list of all known items
                                                          all_items = event.data.items;
                                                          // For every aisle, create a reference in the appropriate store
                                                          event.data.aisles.forEach(function(aisle)
                                                                                    {
                                                                                        stores[aisle.store].aisles.push({name:aisle.name,
                                                                                                                         index:aisle.index});
                                                                                    });
                                                          // Finally, for each item with a known location, put it in the right htable
                                                          event.data.item_locations.forEach(function(store)
                                                                                            {
                                                                                                store.aisles.forEach(function(aisle)
                                                                                                                     {
                                                                                                                         aisle.items.forEach(function(item)
                                                                                                                                             {
                                                                                                                                                 stores[store.store_name].item_locations[item] = aisle.aisle_name;
                                                                                                                                             });
                                                                                                                     });
											    });
							  // Also, consider that we may now have moved
							  current_store = getNearestStoreTo(GPSTracker.getLocation());
							  setCurrentList(event.data.list);
                                                          StoreStore.emitChange();
                                                      }
                                                      if (event.operation == "set_item_location")
                                                      {
                                                          stores[event.data.store].item_locations[event.data.item] = event.data.location;
                                                          // Also set the location of the item on the current list, if present
                                                          // This may trigger a relayout of the table if the item has moved
                                                          current_list.forEach(function(item)
                                                                               {
                                                                                   if (item.name == event.data.item)
                                                                                       item.location = event.data.location;
                                                                               });
                                                          ensureAisleExists(event.data.store, event.data.location);
                                                          StoreStore.emitChange();
                                                          // Also advise the server of this realization
                                                          if (event.origin == 'client')
                                                              ServerConnection.sendMessage(event);
                                                      }
                                                      if (event.operation == "got_item" && event.data.location != "unknown")
                                                      {
                                                          // Delete the item from the list in any case - if the server is responding, then we will
                                                          // waste some time processing a meaningless delete_item, but it wont really matter
                                                          current_list = current_list.filter(function(a) {return a.name != event.data.name});
                                                          StoreStore.emitChange();
                                                          // And also tell the server
                                                          ServerConnection.sendMessage(event);
                                                      }
                                                      if (event.operation == "delete_item")
                                                      {
                                                          // The server wants us to remove an item
                                                          current_list = current_list.filter(function(a) {return a.name != event.data.name});
                                                          StoreStore.emitChange();
                                                      }
                                                      if (event.operation == "add_list_item")
                                                      {
                                                          // The server wants us to add an item
                                                          var found = false;
                                                          for (var i = 0; i < current_list.length; i++)
                                                          {
                                                              if (current_list[i].name == event.data.name)
                                                              {
                                                                  found = true;
                                                                  break;
                                                              }
                                                          }
                                                          if (!found)
                                                          {
                                                              console.log("Adding item " + event.data.name);
                                                              addItemToCurrentList(event.data);
                                                              StoreStore.emitChange();                                                                     
                                                          }
                                                          else
                                                          {
                                                              console.log("Already have " + event.data);
                                                          }
                                                      }
                                                      if (event.operation == "new_item")
                                                      {
                                                          // The user wants to add an item
                                                          // First, add it locally
                                                          console.log("Adding " + event.data);
                                                          all_items.push(event.data);
                                                          addItemToCurrentList(event.data);
                                                          StoreStore.emitChange();
                                                          // then tell the server
                                                          ServerConnection.sendMessage(event);
                                                      }
                                                      if (event.operation == "want_item")
                                                      {
                                                          // The user wants to add an existing item
                                                          // First, add it locally
                                                          addItemToCurrentList(event.data);
                                                          StoreStore.emitChange();
                                                          // then tell the server
                                                          ServerConnection.sendMessage(event);
                                                      }
                                                      if (event.operation == "login")
                                                      {
                                                          ServerConnection.sendMessage(event);
                                                      }
                                                      if (event.operation == "set_store_location")
                                                      {
                                                          stores[event.data.name].location = {latitude:event.data.latitude,
                                                                                              longitude:event.data.longitude};
                                                          if (event.origin == 'client')
                                                              ServerConnection.sendMessage(event);
                                                      }
                                                      if (event.operation == "new_store")
                                                      {
                                                          if (stores[event.data.name] === undefined)
                                                          {
                                                              stores[event.data.name] = {};
                                                              stores[event.data.name].aisles = [];
                                                              stores[event.data.name].item_locations = {};
                                                          }
                                                          if (event.origin == 'client')
                                                              ServerConnection.sendMessage(event);
                                                      }
                                                      if (event.operation == "new_aisle")
                                                      {
                                                          ensureAisleExists(event.data.store, event.data.name);
                                                          if (event.origin == "client")
                                                              ServerConnection.sendMessage(event);
                                                          
                                                      }
                                                      if (event.operation == "set_store")
                                                      {
                                                          console.log('Store is now ' + event.data.name);                                                          
                                                          current_store = event.data.name;
                                                          relocateItems();
                                                          restoreDeferredItems();
                                                          StoreStore.emitChange();
                                                      }
                                                      if (event.operation == "moved")
                                                      {
                                                          var new_store = getNearestStoreTo(event.data.position);
                                                          if (new_store != current_store)
                                                          {
                                                              current_store = new_store
                                                              StoreStore.emitChange();
                                                          }
                                                          restoreDeferredItems();
                                                      }
                                                      if (event.operation == "defer")
                                                      {
                                                          if (deferred_items.indexOf(event.data.name) == -1)
                                                          {
                                                              deferred_items.push(event.data.name);
                                                              localStorage.setItem("deferred_items", JSON.stringify(deferred_items));
                                                              current_list = current_list.filter(function(a) {return a.name != event.data.name});
                                                              StoreStore.emitChange();
                                                          }
                                                      }
                                                      if (event.operation == "delete_store")
                                                      {
                                                          if (event.data.store == 'home')
                                                          {
                                                              // You can never delete the home store since we must always be /somewhere/
                                                              if (event.origin == 'client')
                                                                  alert('You cannot delete the home store');
                                                          }
                                                          else
                                                          {
                                                              delete stores[event.data.store];
                                                              if (current_store == event.data.store)
                                                              {
                                                                  // Hmm. First we must pick another store. If this is the last store, we could raise an alert
                                                                  // However, what if someone ELSE has deleted all the stores?
                                                                  current_store = getNearestStoreTo(GPSTracker.getLocation());
                                                              }
                                                              if (event.origin == "client")
                                                                  ServerConnection.sendMessage(event);
                                                              StoreStore.emitChange();
                                                          }
                                                      }
                                                      if (event.operation == "delete_aisle")
                                                      {
                                                          // FIXME: implement
                                                      }
                                                      if (event.operation == "move_aisle_up")
                                                      {
                                                          var prev_aisle;
                                                          var this_aisle;
                                                          stores[event.data.store].aisles.forEach(function(aisle)
                                                                                                  {
                                                                                                      if (aisle.name == event.data.name)
                                                                                                          this_aisle = aisle;
                                                                                                  });
                                                          if (this_aisle.index > 0)
                                                          {
                                                              stores[event.data.store].aisles.forEach(function(aisle)
                                                                                                      {
                                                                                                          if (aisle.index == this_aisle.index - 1)
                                                                                                              prev_aisle = aisle;
                                                                                                      });                                
                                                              ServerConnection.sendMessage({operation: "set_aisle_indices",
                                                                                            data: {store:event.data.store,
                                                                                                   indices:[{name:event.data.name,
                                                                                                             index:prev_aisle.index},
                                                                                                            {name:prev_aisle.name,
                                                                                                             index:prev_aisle.index+1}]}});
                                                              console.log(this_aisle.name + ' -> '+ prev_aisle.index);
                                                              console.log(prev_aisle.name + ' -> '+ (prev_aisle.index+1));
                                                              this_aisle.index = prev_aisle.index;
                                                              prev_aisle.index = prev_aisle.index+1;
                                                              StoreStore.emitChange();
                                                          }
                                                      }
                                                      if (event.operation == "set_aisle_indices")
                                                      {
                                                          // FIXME: Implement :(
                                                      }

                                                      
                                                  });

module.exports = StoreStore;
