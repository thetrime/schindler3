var React = require('react');
var ServerConnection = require('./ServerConnection');
var StoreStore = require('./StoreStore');
var AppDispatcher = require('./AppDispatcher');
var SettingButton = require('./SettingButton');

module.exports = React.createClass(
    {
        getInitialState: function()
        {
            return {state:"collapsed"};
        },
        expand: function()
        {
            this.setState({state:"expanded"});
        },
        collapse: function()
        {
            this.setState({state:"collapsed"});
        },       
        render: function()
        {
            if (this.state.state == "collapsed")
                return (<button className="app_button settings_button" onClick={this.expand}></button>);
            else
            {
                var settings = [];
                var item = this.props.item;
                var collapse = this.collapse;
                this.props.settings.forEach(function(setting)
                                            {
                                                settings.push(<SettingButton key={setting.label} handler={setting.handler} label={setting.label} collapse={collapse}/>);
                                            });
                settings.push(<button key="Done" className="setting_button" onClick={this.collapse}>Done</button>);
                return (<div className="vertical_layout">
                        {settings}
                        </div>);
            }
        }
    });
