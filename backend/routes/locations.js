const express = require('express');
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const User = require('../models/User');
const Route = require('../models/Route');

const router = express.Router();

// @route   POST /api/locations/update
// @desc    Update user's current location
// @access  Private
router.post('/update', [
  auth,
  body('latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitude must be between -90 and 90'),
  body('longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude must be between -180 and 180'),
  body('accuracy')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Accuracy must be a positive number'),
  body('altitude')
    .optional()
    .isFloat()
    .withMessage('Altitude must be a number'),
  body('speed')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Speed must be a positive number'),
  body('heading')
    .optional()
    .isFloat({ min: 0, max: 360 })
    .withMessage('Heading must be between 0 and 360')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { latitude, longitude, accuracy, altitude, speed, heading } = req.body;
    const userId = req.user.userId;

    // Update user's last location
    const user = await User.findByIdAndUpdate(
      userId,
      {
        lastLocation: {
          latitude,
          longitude,
          accuracy,
          altitude,
          speed,
          heading,
          timestamp: new Date()
        }
      },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      message: 'Location updated successfully',
      location: user.lastLocation
    });

  } catch (error) {
    console.error('Location update error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error updating location'
    });
  }
});

// @route   GET /api/locations/shared
// @desc    Get locations of users sharing with current user
// @access  Private
router.get('/shared', auth, async (req, res) => {
  try {
    const userId = req.user.userId;

    // Find users who are sharing their location with the current user
    const sharedUsers = await User.findLocationSharingUsers(userId);

    const sharedLocations = sharedUsers.map(user => ({
      id: user._id,
      name: user.name,
      email: user.email,
      location: user.lastLocation,
      lastUpdated: user.lastLocation?.timestamp || user.updatedAt
    }));

    res.json({
      success: true,
      sharedLocations
    });

  } catch (error) {
    console.error('Get shared locations error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting shared locations'
    });
  }
});

// @route   POST /api/locations/share
// @desc    Start/stop sharing location with a user
// @access  Private
router.post('/share', [
  auth,
  body('targetUserId')
    .isMongoId()
    .withMessage('Invalid user ID'),
  body('share')
    .isBoolean()
    .withMessage('Share must be true or false')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { targetUserId, share } = req.body;
    const userId = req.user.userId;

    // Can't share with yourself
    if (targetUserId === userId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot share location with yourself'
      });
    }

    // Check if target user exists
    const targetUser = await User.findById(targetUserId);
    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: 'Target user not found'
      });
    }

    const user = await User.findById(userId);
    
    if (share) {
      // Add to sharing list if not already there
      if (!user.shareLocationWith.includes(targetUserId)) {
        user.shareLocationWith.push(targetUserId);
      }
      user.locationSharingEnabled = true;
    } else {
      // Remove from sharing list
      user.shareLocationWith = user.shareLocationWith.filter(
        id => id.toString() !== targetUserId
      );
      
      // If no one to share with, disable sharing
      if (user.shareLocationWith.length === 0) {
        user.locationSharingEnabled = false;
      }
    }

    await user.save();

    res.json({
      success: true,
      message: share ? 'Location sharing enabled' : 'Location sharing disabled',
      shareLocationWith: user.shareLocationWith
    });

  } catch (error) {
    console.error('Location sharing error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error updating location sharing'
    });
  }
});

// @route   GET /api/locations/history
// @desc    Get user's location history within date range
// @access  Private
router.get('/history', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { startDate, endDate, limit = 1000 } = req.query;

    let query = { userId };

    // Add date range filter if provided
    if (startDate || endDate) {
      query.startTime = {};
      if (startDate) {
        query.startTime.$gte = new Date(startDate);
      }
      if (endDate) {
        query.startTime.$lte = new Date(endDate);
      }
    }

    const routes = await Route.find(query)
      .sort({ startTime: -1 })
      .limit(parseInt(limit))
      .select('startTime endTime locations totalDistance totalDuration averageSpeed');

    res.json({
      success: true,
      routes,
      count: routes.length
    });

  } catch (error) {
    console.error('Location history error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting location history'
    });
  }
});

// @route   DELETE /api/locations/history/:routeId
// @desc    Delete a specific route
// @access  Private
router.delete('/history/:routeId', auth, async (req, res) => {
  try {
    const { routeId } = req.params;
    const userId = req.user.userId;

    const route = await Route.findOneAndDelete({
      _id: routeId,
      userId: userId
    });

    if (!route) {
      return res.status(404).json({
        success: false,
        message: 'Route not found or not authorized'
      });
    }

    res.json({
      success: true,
      message: 'Route deleted successfully'
    });

  } catch (error) {
    console.error('Delete route error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error deleting route'
    });
  }
});

module.exports = router;