var React = require('react');
var AppDispatcher = require('./AppDispatcher');
var ServerConnection = require('./ServerConnection');
var NewItem = require('./NewItem');
var Item = require('./Item');

module.exports = React.createClass(
    {
        addNewAisle: function(aisle)
        {
            AppDispatcher.dispatch({operation:"new_aisle",
                                    origin:"client",
                                    data:{store:this.props.store,
                                          name:aisle.name}});
            AppDispatcher.dispatch({operation:"set_item_location",
                                    origin:"client",
                                    data:{location:aisle.name,
                                          item:this.props.item.name,
                                          store:this.props.store}});
            // Also delete the item from the list
            AppDispatcher.dispatch({operation:"got_item",
                                    data:{location:aisle,
                                          name:this.props.item.name}});

        },
        
        selectAisle: function(aisle)
        {
            AppDispatcher.dispatch({operation:"set_item_location",
                                    origin:"client",
                                    data:{location:aisle.name,
                                          item:this.props.item.name,
                                          store:this.props.store}});
            // Also delete the item from the list
            AppDispatcher.dispatch({operation:"got_item",
                                    data:{location:aisle.name,
                                          name:this.props.item.name}});

        },
        render: function()
        {
            var rows = [];
            var filter = this.props.filterText;
            var exactMatch = false;
            var i = 0;
            if (filter != '' && !exactMatch)
            {
                rows.push(<NewItem name={filter} key={filter} addItem={this.addNewAisle} label="add" zebra={(i++) % 2 == 1}/>);
            }
            var table = this;
            this.props.aisles.sort().forEach(function(aisle)
                                             {
                                                 rows.push(<Item item={aisle} key={aisle.name} onClick={table.selectAisle} label='select' zebra={(i++) % 2 == 1}/>);
                                            });
            return (<div className="table_container vertical_fill">
                    {rows}
                    </div>);
        }
    });
