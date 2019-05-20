var React = require('react');
var SearchBox = require('./SearchBox');
var AisleTable = require('./AisleTable');
var ServerConnection = require('./ServerConnection');
var StoreStore = require('./StoreStore');
var Callout = require('./Callout');

module.exports = React.createClass(
    {
        render: function()
        {
            var options = [];
            this.props.options.forEach(function(option)
                                       {
                                           options.push(<div className="horizontal_fill vertical_layout">
                                                        <button className="horizontal_fill" onClick={option.callback}>{option.label}</button>
                                                        </div>);
                                       });

            
            return (<div className="popup_dialog">
                    <div className="vertical_layout vertical_fill">
                    <div className="horizontal_fill dialog_title">
                    {this.props.title}
                    </div>
                    {options}
                    </div>
                    </div>);
        }
    });
