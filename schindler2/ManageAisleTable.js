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
        },
        
        render: function()
        {
            var rows = [];
            var filter = this.props.filterText;
            var exactMatch = false;
            if (filter != '' && !exactMatch)
            {
                rows.push(<NewItem name={filter} key={filter} addItem={this.addNewAisle} label="add"/>);
            }
            var table = this;
            this.props.aisles.sort().forEach(function(aisle)
                                             {
                                                 var settings  = [{label:'Delete this location in the store',
                                                                   handler:function()
                                                                   {
                                                                       AppDispatcher.dispatch({operation:"delete_aisle",
                                                                                               origin:"client",
                                                                                               data:{name:aisle.name,
                                                                                                     store:this.props.store}});
                                                                   }}];                                                 
                                                 rows.push(<Item item={aisle} key={aisle.name} settings={settings}/>);
                                            });
            return (<div className="table_container vertical_fill">
                    {rows}
                    </div>);
        }
    });
