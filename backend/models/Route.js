const mongoose = require('mongoose');

const locationPointSchema = new mongoose.Schema({
  latitude: {
    type: Number,
    required: true,
    min: -90,
    max: 90
  },
  longitude: {
    type: Number,
    required: true,
    min: -180,
    max: 180
  },
  altitude: {
    type: Number,
    default: null
  },
  accuracy: {
    type: Number,
    default: null
  },
  speed: {
    type: Number,
    default: null
  },
  heading: {
    type: Number,
    default: null
  },
  timestamp: {
    type: Date,
    required: true,
    default: Date.now
  }
});

const routeSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  name: {
    type: String,
    trim: true,
    maxlength: [100, 'Route name cannot be more than 100 characters']
  },
  description: {
    type: String,
    trim: true,
    maxlength: [500, 'Description cannot be more than 500 characters']
  },
  startTime: {
    type: Date,
    required: true
  },
  endTime: {
    type: Date,
    required: true
  },
  locations: [locationPointSchema],
  totalDistance: {
    type: Number,
    default: 0 // in meters
  },
  totalDuration: {
    type: Number,
    default: 0 // in seconds
  },
  averageSpeed: {
    type: Number,
    default: 0 // in m/s
  },
  maxSpeed: {
    type: Number,
    default: 0 // in m/s
  },
  elevationGain: {
    type: Number,
    default: 0 // in meters
  },
  elevationLoss: {
    type: Number,
    default: 0 // in meters
  },
  isPublic: {
    type: Boolean,
    default: false
  },
  tags: [{
    type: String,
    trim: true,
    maxlength: 20
  }],
  weather: {
    temperature: Number,
    humidity: Number,
    windSpeed: Number,
    conditions: String
  }
}, {
  timestamps: true
});

// Indexes for efficient queries
routeSchema.index({ userId: 1, startTime: -1 });
routeSchema.index({ userId: 1, endTime: -1 });
routeSchema.index({ 'locations.timestamp': 1 });
routeSchema.index({ isPublic: 1, startTime: -1 });

// Calculate route statistics before saving
routeSchema.pre('save', function(next) {
  if (this.locations && this.locations.length > 1) {
    this.calculateRouteStats();
  }
  next();
});

// Method to calculate route statistics
routeSchema.methods.calculateRouteStats = function() {
  const locations = this.locations;
  if (locations.length < 2) return;

  let totalDistance = 0;
  let maxSpeed = 0;
  let elevationGain = 0;
  let elevationLoss = 0;
  let previousElevation = null;

  for (let i = 1; i < locations.length; i++) {
    const prev = locations[i - 1];
    const curr = locations[i];

    // Calculate distance using Haversine formula
    const distance = this.calculateDistance(
      prev.latitude, prev.longitude,
      curr.latitude, curr.longitude
    );
    totalDistance += distance;

    // Track max speed
    if (curr.speed && curr.speed > maxSpeed) {
      maxSpeed = curr.speed;
    }

    // Calculate elevation changes
    if (prev.altitude !== null && curr.altitude !== null) {
      const elevationChange = curr.altitude - prev.altitude;
      if (elevationChange > 0) {
        elevationGain += elevationChange;
      } else {
        elevationLoss += Math.abs(elevationChange);
      }
    }
  }

  this.totalDistance = totalDistance;
  this.maxSpeed = maxSpeed;
  this.elevationGain = elevationGain;
  this.elevationLoss = elevationLoss;

  // Calculate duration and average speed
  const duration = (this.endTime - this.startTime) / 1000; // in seconds
  this.totalDuration = duration;
  this.averageSpeed = duration > 0 ? totalDistance / duration : 0;
};

// Haversine formula for calculating distance between two points
routeSchema.methods.calculateDistance = function(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = this.toRadians(lat2 - lat1);
  const dLon = this.toRadians(lon2 - lon1);
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(this.toRadians(lat1)) * Math.cos(this.toRadians(lat2)) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
};

routeSchema.methods.toRadians = function(degrees) {
  return degrees * (Math.PI/180);
};

// Static method to find routes within a date range
routeSchema.statics.findByDateRange = function(userId, startDate, endDate) {
  return this.find({
    userId: userId,
    startTime: { $gte: startDate },
    endTime: { $lte: endDate }
  }).sort({ startTime: -1 });
};

module.exports = mongoose.model('Route', routeSchema);