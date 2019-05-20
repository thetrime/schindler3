var React = require('react');
var SearchBox = require('./SearchBox');
var AisleTable = require('./AisleTable');
var ServerConnection = require('./ServerConnection');
var StoreStore = require('./StoreStore');
var Callout = require('./Callout');
var ManageAisleTable = require('./ManageAisleTable');
var AppDispatcher = require('./AppDispatcher');
var AisleManagementBanner = require('./AisleManagementBanner');

function getStateFromStore()
{
    return {aisles: StoreStore.getAislesForCurrentStore()};
}


module.exports = React.createClass(
    {
        getInitialState: function()
        {
            return {filterText: '',
                    aisles: StoreStore.getAislesForCurrentStore()};
        },

        onChange: function()
        {
            this.setState(getStateFromStore());
        },
        
        redoSearch: function(value)
        {
            this.setState({filterText: value});
        },
       
        addAisle: function(item)
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
            {
                // This mode is for when the user is being asked to identify the location
                // of an item in a store
                return (<div className="vertical_layout vertical_fill">
                        <Callout label={"Where did you get " + this.props.item.name + "?"} not_sure={{label:"I forgot",
                                                                                                      handler:function()
                                                                                                      {
                                                                                                          AppDispatcher.dispatch({operation:"got_item",
                                                                                                                                  data:{location:null,
                                                                                                                                        name:this.props.item.name}});
                                                                                                      }.bind(this)}}/>
                        <SearchBox filterText={this.state.filterText} redoSearch={this.redoSearch}/>
                        <AisleTable aisles={this.state.aisles} filterText={this.state.filterText.trim()} redoSearch={this.redoSearch} store={StoreStore.getCurrentStore()} item={this.props.item} className="horizontal_fill vertical_fill"/> 
                        </div>);
            }
            else
            {
                // This mode is for maintenance of the aisles in a store
                return (<div className="vertical_layout vertical_fill">
                        <SearchBox filterText={this.state.filterText} redoSearch={this.redoSearch}/>
                        <AisleManagementBanner store={this.props.store}/>
                        <ManageAisleTable aisles={this.state.aisles} filterText={this.state.filterText.trim()} redoSearch={this.redoSearch} store={this.props.store} className="horizontal_fill vertical_fill"/> 
                        </div>);

            }
        }
    });
