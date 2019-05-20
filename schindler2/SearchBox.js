var React = require('react');
var AppDispatcher = require('./AppDispatcher');


module.exports = React.createClass(
    {
        searchChanged : function()
        {
            this.props.redoSearch(this.refs.searchField.value);
        },
        
        render: function()
        {
            return (<form className="search_bar">
                    <input type="search" placeholder="Search..." className="search_field" autoCapitalize="off" onChange={this.searchChanged} value={this.props.filterText} ref="searchField"/>
                    </form>);
        }
    });
