const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Name is required'],
    trim: true,
    maxlength: [50, 'Name cannot be more than 50 characters']
  },
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    lowercase: true,
    trim: true,
    match: [/^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/, 'Please enter a valid email']
  },
  password: {
    type: String,
    required: [true, 'Password is required'],
    minlength: [6, 'Password must be at least 6 characters'],
    select: false // Don't include password in queries by default
  },
  profilePicture: {
    type: String,
    default: null
  },
  isActive: {
    type: Boolean,
    default: true
  },
  shareLocationWith: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  locationSharingEnabled: {
    type: Boolean,
    default: false
  },
  lastLocation: {
    latitude: Number,
    longitude: Number,
    timestamp: Date,
    accuracy: Number
  },
  preferences: {
    trackingAccuracy: {
      type: String,
      enum: ['high', 'medium', 'low'],
      default: 'medium'
    },
    backgroundTracking: {
      type: Boolean,
      default: true
    },
    dataRetentionDays: {
      type: Number,
      default: 365
    }
  }
}, {
  timestamps: true
});

// Index for geospatial queries
userSchema.index({ 'lastLocation.latitude': 1, 'lastLocation.longitude': 1 });

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Compare password method
userSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Remove sensitive data when converting to JSON
userSchema.methods.toJSON = function() {
  const userObject = this.toObject();
  delete userObject.password;
  return userObject;
};

// Static method to find users sharing location with a specific user
userSchema.statics.findLocationSharingUsers = function(userId) {
  return this.find({
    shareLocationWith: userId,
    locationSharingEnabled: true,
    isActive: true
  }).select('name email lastLocation');
};

module.exports = mongoose.model('User', userSchema);