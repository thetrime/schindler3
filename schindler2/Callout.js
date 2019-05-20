var React = require('react');
var AppDispatcher = require('./AppDispatcher');

module.exports = React.createClass(
    {
        render: function()
        {
            return (<div className="horizontal_fill info_callout horizontal_layout">
                    <div className="horizontal_fill vertical_center">
                    <span>
                    {this.props.label}
                    </span>
                    </div>
                    <button onClick={this.props.not_sure.handler}>{this.props.not_sure.label}</button>
                    </div>)
        }
    });



                    
