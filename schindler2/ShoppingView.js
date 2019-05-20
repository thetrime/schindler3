var React = require('react');
var StoreStore = require('./StoreStore');
var SearchBox = require('./SearchBox');
var ItemTable = require('./ItemTable');
var ServerConnection = require('./ServerConnection');

function getStateFromStore()
{
    return {items: StoreStore.getCurrentList(),
            all_items: StoreStore.getItemsForCurrentStore()};
}


module.exports = React.createClass(
    {
        getInitialState: function()
        {
            return {filterText: '',
                    all_items: StoreStore.getItemsForCurrentStore(),
                    items: StoreStore.getCurrentList()};
        },

        onChange: function()
        {
            this.setState(getStateFromStore());
        },
        
        redoSearch: function(value)
        {
            this.setState({filterText: value});
        },

        gotItem: function(item)
        {
            this.setState({items: this.state.items.filter(function(existing_item)
                                                          {
                                                              return existing_item.name != item.name;
                                                          })});
        },
        
        addItem: function(item)
        {
            this.setState({items: this.state.items.concat([item])});
        },
        
        componentWillMount: function()
        {
            StoreStore.addChangeListener(this.onChange);
        },

        componentWillUnmount: function()
        {
            StoreStore.removeChangeListener(this.onChange);
        },
        
        render: function()
        {
            return (<div className="vertical_layout vertical_fill">
                    <SearchBox filterText={this.state.filterText} redoSearch={this.redoSearch} className="horizontal_fill"/>
                    <ItemTable list_items={this.state.items} all_items={this.state.all_items} filterText={this.state.filterText.trim()} redoSearch={this.redoSearch} className="horizontal_fill vertical_fill"/>
                    </div>);
        }
    });
