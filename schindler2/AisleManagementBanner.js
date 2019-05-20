var React = require('react');
var AppDispatcher = require('./AppDispatcher');

module.exports = React.createClass(
    {
        done: function()
        {
            AppDispatcher.dispatch({operation:"manage_store_complete",
                                    data:{}});
        },
        render: function()
        {
            return (<div className="horizontal_fill info_callout horizontal_layout">
                    <div className="horizontal_fill vertical_center">
                    <span>
                    Managing {this.props.store}
                    </span>
                    </div>
                    <button onClick={this.done}>Done</button>
                    </div>)
        }
    });



                    
