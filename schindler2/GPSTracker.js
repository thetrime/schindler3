var AppDispatcher = require('./AppDispatcher');   

var location = {latitude:0,
                longitude:0};

function toRadians(φ)
{
    return (φ / 180) * Math.PI;
}


var GPSTracker =
    {
        initialize: function()
        {
            if (navigator.geolocation)
            {
                var that = this;
                // Check it immediately on startup, then every 2 minutes thereafter
                console.log("Checking the first time");
                navigator.geolocation.getCurrentPosition(that.updatePosition.bind(that));
                setInterval(function()
                            {
                                console.log("Checking a subsequent time");
                                navigator.geolocation.getCurrentPosition(that.updatePosition.bind(that));
                            }, 120000);
            }
        },
        
        updatePosition: function(position)
        {
            var delta = this.haversine(position.coords, location);
            if (delta > 500)
            {
                console.log("We have moved " + delta + " metres");
                location = position.coords;
                AppDispatcher.dispatch({operation:"moved",
                                        data:{position:location}});
            }
        },

        getLocation: function()
        {
            return location;
        },
        
        haversine: function(a, b)
        {
            var R = 6371000;
            var φ1 = toRadians(a.latitude);
            var φ2 = toRadians(b.latitude);
            var Δφ = toRadians(b.latitude-a.latitude)
            var Δλ = toRadians(b.longitude-a.longitude);
            var a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
                Math.cos(φ1) * Math.cos(φ2) *
                Math.sin(Δλ/2) * Math.sin(Δλ/2);
            var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
            return R * c;
        }
    };

module.exports = GPSTracker;
