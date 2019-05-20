var React = require('react');
var AppDispatcher = require('./AppDispatcher');

module.exports = React.createClass(
    {
        login: function()
        {
            AppDispatcher.dispatch({operation:"login",
                                    data:{username:this.state.username,
                                          // FIXME: Sending the password in plain text is obviously a terrible idea.
                                          // Instead send a hash of the password plus a random salt, and then the salt.
                                          // But we have to send it at least once if we want the server to know it
                                          // For now, just ignore the obviously terrible security. It will be fixed before
                                          // I get too much further.
                                          password:this.state.password}});
        },

        inputChanged: function()
        {
            this.setState({username:this.refs.userName.value,
                           password:this.refs.password.value});
        },


        getInitialState: function()
        {
            return {username:'',
                    password:''};
        },
        
        render: function()
        {
            return (<div className="login vertical_fill vertical_layout">
                      <div className="horizontal_layout login_parent">
                        <div className="login_box">
                          <div>
                            <h2>Schindler</h2>
                            <div>
                              <div id="username_div">
                                <label htmlFor="username">Username:</label>
                                <div>
                                  <input type="text" id="username" value={this.state.username} onChange={this.inputChanged} ref="userName" autoCapitalize="off" autoComplete="off" autoCorrect="off" spellCheck="false"/>
                                </div>
                              </div>
                              <div id="password_div">
                                <label htmlFor="password">Password:</label>
                                <div>
                                  <input type="password" id="password" value={this.state.password} onChange={this.inputChanged} ref="password"/>
                                </div>
                             </div>
                           </div>
                        </div>
                        <button onClick={this.login} className="login_button">Login</button>
                      </div>
                    </div>
                    </div>);
        }
    });
