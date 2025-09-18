const express = require('express');
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const User = require('../models/User');

const router = express.Router();

// @route   GET /api/users/profile
// @desc    Get user profile
// @access  Private
router.get('/profile', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId)
      .populate('shareLocationWith', 'name email');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      user
    });

  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting profile'
    });
  }
});

// @route   PUT /api/users/profile
// @desc    Update user profile
// @access  Private
router.put('/profile', [
  auth,
  body('name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Name must be between 2 and 50 characters'),
  body('email')
    .optional()
    .isEmail()
    .normalizeEmail()
    .withMessage('Please enter a valid email')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { name, email } = req.body;
    const userId = req.user.userId;

    // Check if email is already taken by another user
    if (email) {
      const existingUser = await User.findOne({ 
        email, 
        _id: { $ne: userId } 
      });
      
      if (existingUser) {
        return res.status(400).json({
          success: false,
          message: 'Email is already taken'
        });
      }
    }

    const updateData = {};
    if (name) updateData.name = name;
    if (email) updateData.email = email;

    const user = await User.findByIdAndUpdate(
      userId,
      updateData,
      { new: true, runValidators: true }
    ).populate('shareLocationWith', 'name email');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      message: 'Profile updated successfully',
      user
    });

  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error updating profile'
    });
  }
});

// @route   PUT /api/users/preferences
// @desc    Update user preferences
// @access  Private
router.put('/preferences', [
  auth,
  body('trackingAccuracy')
    .optional()
    .isIn(['high', 'medium', 'low'])
    .withMessage('Tracking accuracy must be high, medium, or low'),
  body('backgroundTracking')
    .optional()
    .isBoolean()
    .withMessage('Background tracking must be true or false'),
  body('dataRetentionDays')
    .optional()
    .isInt({ min: 1, max: 3650 })
    .withMessage('Data retention must be between 1 and 3650 days')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { trackingAccuracy, backgroundTracking, dataRetentionDays } = req.body;
    const userId = req.user.userId;

    const updateData = { preferences: {} };
    if (trackingAccuracy) updateData.preferences.trackingAccuracy = trackingAccuracy;
    if (typeof backgroundTracking === 'boolean') updateData.preferences.backgroundTracking = backgroundTracking;
    if (dataRetentionDays) updateData.preferences.dataRetentionDays = dataRetentionDays;

    const user = await User.findByIdAndUpdate(
      userId,
      { $set: updateData },
      { new: true, runValidators: true }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      message: 'Preferences updated successfully',
      preferences: user.preferences
    });

  } catch (error) {
    console.error('Update preferences error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error updating preferences'
    });
  }
});

// @route   GET /api/users/search
// @desc    Search for users by email
// @access  Private
router.get('/search', [
  auth,
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please enter a valid email')
], async (req, res) => {
  try {
    const { email } = req.query;
    
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email parameter is required'
      });
    }

    const user = await User.findOne({ 
      email: email.toLowerCase(),
      isActive: true 
    }).select('name email');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Don't return the current user in search results
    if (user._id.toString() === req.user.userId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot add yourself as a friend'
      });
    }

    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email
      }
    });

  } catch (error) {
    console.error('User search error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error searching for user'
    });
  }
});

// @route   POST /api/users/friends/add
// @desc    Add a friend for location sharing
// @access  Private
router.post('/friends/add', [
  auth,
  body('friendId')
    .isMongoId()
    .withMessage('Invalid friend ID')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { friendId } = req.body;
    const userId = req.user.userId;

    // Can't add yourself
    if (friendId === userId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot add yourself as a friend'
      });
    }

    // Check if friend exists
    const friend = await User.findById(friendId);
    if (!friend || !friend.isActive) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Add friend to current user's sharing list
    const user = await User.findById(userId);
    if (!user.shareLocationWith.includes(friendId)) {
      user.shareLocationWith.push(friendId);
      await user.save();
    }

    res.json({
      success: true,
      message: 'Friend added successfully',
      friend: {
        id: friend._id,
        name: friend.name,
        email: friend.email
      }
    });

  } catch (error) {
    console.error('Add friend error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error adding friend'
    });
  }
});

// @route   DELETE /api/users/friends/:friendId
// @desc    Remove a friend from location sharing
// @access  Private
router.delete('/friends/:friendId', auth, async (req, res) => {
  try {
    const { friendId } = req.params;
    const userId = req.user.userId;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Remove friend from sharing list
    user.shareLocationWith = user.shareLocationWith.filter(
      id => id.toString() !== friendId
    );

    // If no friends left, disable location sharing
    if (user.shareLocationWith.length === 0) {
      user.locationSharingEnabled = false;
    }

    await user.save();

    res.json({
      success: true,
      message: 'Friend removed successfully'
    });

  } catch (error) {
    console.error('Remove friend error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error removing friend'
    });
  }
});

// @route   GET /api/users/friends
// @desc    Get user's friends list
// @access  Private
router.get('/friends', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId)
      .populate('shareLocationWith', 'name email lastLocation');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const friends = user.shareLocationWith.map(friend => ({
      id: friend._id,
      name: friend.name,
      email: friend.email,
      lastLocation: friend.lastLocation,
      lastUpdated: friend.lastLocation?.timestamp || friend.updatedAt
    }));

    res.json({
      success: true,
      friends
    });

  } catch (error) {
    console.error('Get friends error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting friends list'
    });
  }
});

// @route   DELETE /api/users/account
// @desc    Delete user account
// @access  Private
router.delete('/account', auth, async (req, res) => {
  try {
    const userId = req.user.userId;

    // Soft delete - just deactivate the account
    const user = await User.findByIdAndUpdate(
      userId,
      { 
        isActive: false,
        locationSharingEnabled: false,
        shareLocationWith: []
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
      message: 'Account deactivated successfully'
    });

  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error deleting account'
    });
  }
});

module.exports = router;