var React = require('react');
var AppDispatcher = require('./AppDispatcher');
var ServerConnectionStore = require('./ServerConnectionStore');

function getConnectionStatus()
{
    return ServerConnectionStore.getConnectionStatus();
}


module.exports = React.createClass(
    {
        getInitialState: function()
        {
            return {status: getConnectionStatus()};
        },

        onChange: function()
        {
            this.setState({status: getConnectionStatus()});
        },
        
        render: function()
        {
            if (this.state.status == "connected" || this.state.status == "new")
                return (<div/>);
            else
                return (<div className="connection_bar">Reestablishing connection...</div>);
        },

        componentWillMount: function()
        {
            ServerConnectionStore.addChangeListener(this.onChange);
        },

        componentWillUnmount: function()
        {
            ServerConnectionStore.removeChangeListener(this.onChange);
        }


    });
