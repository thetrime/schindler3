var React = require('react');
var AppDispatcher = require('./AppDispatcher');
var ItemSettings = require('./ItemSettings');

module.exports = React.createClass(
    {
        onClick: function()
        {
            this.props.onClick(this.props.item);
        },
        render: function()
        {
            var label = this.props.label;
            var className = "app_button " + this.props.label + "_button";
            var settings = [];
            var main = [];
            if (this.props.settings != undefined)
            {
                settings = [(<div className="settings_column" key="settings_column"><ItemSettings item={this.props.item} settings={this.props.settings}/></div>)];
            }
            if (this.props.onClick != undefined)
            {
                main = [(<div className="button_column" key="button_column"><button className={className} onClick={this.onClick}></button></div>)];
            }
            var zebraClass = this.props.zebra?" zebra":"";
            return (<div className={"horizontal_layout horizontal_fill" + zebraClass}>
                    <div className="horizontal_fill item">
                    <div className="horizontal_fill item_label">{this.props.item.name}</div>
                    {settings}
                    {main}
                    </div>
                    </div>);
        }
    });
