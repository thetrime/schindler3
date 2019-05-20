var React = require('react');
var AppDispatcher = require('./AppDispatcher');

module.exports = React.createClass(
    {
        addItem: function()
        {
            this.props.addItem({name:this.props.name});
        },
        render: function()
        {
            var zebraClass = this.props.zebra?" zebra":"";
            return (<div className={"horizontal_layout horizontal_fill" + zebraClass}>
                    <div className="horizontal_fill item">
                    <div className="horizontal_fill item_label">{this.props.name}</div>
                    <div className="button_column" colSpan="2"><button className="app_button add_button" onClick={this.addItem}></button></div>
                    </div>
                    </div>);
            
        }
    });
