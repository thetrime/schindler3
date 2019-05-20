var React = require('react');
var AppDispatcher = require('./AppDispatcher');

module.exports = React.createClass(
    {
        render: function()
        {
            return (<div className="horizontal_fill location">
                    {this.props.location}
                    </div>);
                    
        }
    });
