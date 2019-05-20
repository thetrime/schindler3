var React = require('react');
var AppDispatcher = require('./AppDispatcher');
var ServerConnection = require('./ServerConnection');
var Location = require('./Location');
var Item = require('./Item');
var NewItem = require('./NewItem');
var PopupDialog = require('./PopupDialog');
var StoreStore = require('./StoreStore');

function item_comparator(a, b)
{
    if (a.name > b.name)
        return 1;
    else if (a.name < b.name)
        return -1;
    else
        return 0;
}

module.exports = React.createClass(
    {     
        addItem: function(item)
        {
            AppDispatcher.dispatch({operation:"new_item",
                                    data:{name:item.name,
                                          location:"unknown"}});
            this.props.redoSearch('');
        },
        wantItem: function(item)
        {
            AppDispatcher.dispatch({operation:"want_item",
                                    data:{name:item.name}});
            this.props.redoSearch('');
        },
        gotItem: function(item)
        {
            AppDispatcher.dispatch({operation:"got_item",
                                    data:{name:item.name,
                                          location:item.location}});
        },
        render: function()
        {
            var rows = [];
            var groups = {};
            var filter = this.props.filterText;
            var exactMatch = false;
            var allItems = this.props.list_items;
            if (filter != '')
            {
                // Need to determine which of these items are in this.props.all_items, and mark them appropriately so that we can
                // distinguish 'Add Item' from 'Got It!' and call the appropriate function when clicked
                // FIXME: This is really inefficient. We must be able to do better...
                allItems = this.props.all_items;
                var listItems = this.props.list_items;
                console.log('Searching');
                allItems.forEach(function(list_item)
                                 {
                                     list_item.on_list = false;
                                     for (var i = 0; i < listItems.length; i++)
                                     {
                                         if (listItems[i].name == list_item.name)
                                         {
                                             console.log("Found " + listItems[i].name);
                                             list_item.on_list = true;
                                         }
                                     }
                                 });
            }
            allItems.forEach(function(item)
                             {
                                 if (filter != '' && item.name.indexOf(filter) != 0)
                                     return;
                                 if (filter != '' && item.name == filter)
                                     exactMatch = true;
                                 if (groups[item.location] === undefined)
                                     groups[item.location] = {location: item.location,
                                                              items: [item]};
                                 else
                                     groups[item.location].items.push(item);
                             });
            var table = this;
            var i = 0;
            if (filter != '' && !exactMatch)
            {
                rows.push(<NewItem name={filter} key={filter} addItem={table.addItem} label="add" zebra={(i++) % 2 == 1}/>);
            }
            Object.keys(groups).sort().forEach(function(group)
                                               {
                                                   if (group == "$beyond" && filter == '')
                                                       return;
                                                   if (group == "$beyond" && filter != '')
                                                       rows.push(<Location key={groups[group].location} location="Not Available Here"/>);
                                                   else
                                                       rows.push(<Location key={groups[group].location} location={groups[group].location}/>);
                                                   groups[group].items.sort(item_comparator).forEach(function(item)
                                                                                                     {
                                                                                                         var settings = [];
                                                                                                         if (item.on_list)
                                                                                                         {
                                                                                                             var store = StoreStore.getCurrentStore();
                                                                                                             if (store != undefined)
                                                                                                             {
                                                                                                                 settings.push({label:'Hide for this store',
                                                                                                                                handler:function()
                                                                                                                                {
                                                                                                                                    AppDispatcher.dispatch({operation:"set_item_location",
                                                                                                                                                            origin:"client",
                                                                                                                                                            data:{location:"$beyond",
                                                                                                                                                                  item:item.name,
                                                                                                                                                                  store:store}});
                                                                                                                                }});
                                                                                                             
                                                                                                                 settings.push({label:'Remove from current location',
                                                                                                                                handler:function()
                                                                                                                                {
                                                                                                                                    AppDispatcher.dispatch({operation:"set_item_location",
                                                                                                                                                            origin:"client",
                                                                                                                                                            data:{location:"unknown",
                                                                                                                                                                  item:item.name,
                                                                                                                                                                  store:store}});
                                                                                                                                }});
                                                                                                             }
                                                                                                             settings.push({label:'Get it next time',
                                                                                                                            handler: function()
                                                                                                                            {
                                                                                                                                AppDispatcher.dispatch({operation:"defer",
                                                                                                                                                        data:{name:item.name}});
                                                                                                                            }});
                                                                                                         }
                                                                                                         else
                                                                                                             settings = undefined;
                                                                                                         rows.push(<Item item={item}
                                                                                                                   zebra={(i++) % 2 == 1}
                                                                                                                   key={item.name}
                                                                                                                   onClick={item.on_list?table.gotItem:table.wantItem}
                                                                                                                   label={item.on_list?"got_it":"add"}
                                                                                                                   settings={settings}/>);
                                                                                                     });
                                                              });
            
            return (<div className="table_container vertical_fill">
                    {rows}
                    </div>);
        }
    });
