var React = require('react');
var AppDispatcher = require('./AppDispatcher');

module.exports = React.createClass(
    {
        onClick: function()
        {
            this.props.handler();
            this.props.collapse();
        },
        render: function()
        {
            return (<button className="setting_button" onClick={this.onClick}>{this.props.label}</button>);
        }
    });
