var React = require('react');
var AppDispatcher = require('./AppDispatcher');

module.exports = React.createClass(
    {
        logout: function()
        {
            AppDispatcher.dispatch({operation:"logout"});
        },
        
        render: function()
        {
            return (<button onClick={this.logout} className="user_button"></button>);
        }
    });
