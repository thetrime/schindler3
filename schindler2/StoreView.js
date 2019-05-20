var React = require('react');
var SearchBox = require('./SearchBox');
var StoreTable = require('./StoreTable');
var ServerConnection = require('./ServerConnection');
var StoreStore = require('./StoreStore');
var Callout = require('./Callout');
var AppDispatcher = require('./AppDispatcher');

function getStateFromStore()
{
    return {stores: StoreStore.getStoreNames()};
}


module.exports = React.createClass(
    {
        getInitialState: function()
        {
            return {filterText: '',
                    stores: StoreStore.getStoreNames()};
        },

        onChange: function()
        {
            this.setState(getStateFromStore());
        },

        redoSearch: function(value)
        {
            this.setState({filterText: value});
        },
       
        addStore: function(item)
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
            if (this.props.item != undefined)
                return (<div className="vertical_layout vertical_fill">
                        <Callout label="Where are you?" not_sure={{label:"Not sure",
                                                                   handler: function()
                                                                   {
                                                                       // User does not want to be bothered with this. Just delete the item locally and on the server
                                                                       AppDispatcher.dispatch({operation:"got_item",
                                                                                               data:{location:null,
                                                                                                     name:this.props.item.name}});
                                                                   }.bind(this)}}/>
                        <SearchBox filterText={this.state.filterText} redoSearch={this.redoSearch}/>                        
                        <StoreTable stores={this.state.stores} filterText={this.state.filterText.trim()} redoSearch={this.redoSearch} className="horizontal_fill vertical_fill"/> 
                        </div>);             
            else
                return (<div className="vertical_layout vertical_fill">
                        <SearchBox filterText={this.state.filterText} redoSearch={this.redoSearch}/>
                        <StoreTable stores={this.state.stores} filterText={this.state.filterText.trim()} redoSearch={this.redoSearch} className="horizontal_fill vertical_fill"/> 
                        </div>); 
        }
    });
