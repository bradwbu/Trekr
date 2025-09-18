const express = require('express');
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const Route = require('../models/Route');

const router = express.Router();

// @route   POST /api/routes
// @desc    Create a new route
// @access  Private
router.post('/', [
  auth,
  body('name')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Route name must be between 1 and 100 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description cannot exceed 500 characters'),
  body('locations')
    .isArray({ min: 2 })
    .withMessage('Route must have at least 2 locations'),
  body('locations.*.latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitude must be between -90 and 90'),
  body('locations.*.longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude must be between -180 and 180'),
  body('locations.*.timestamp')
    .isISO8601()
    .withMessage('Timestamp must be a valid ISO 8601 date'),
  body('startTime')
    .isISO8601()
    .withMessage('Start time must be a valid ISO 8601 date'),
  body('endTime')
    .isISO8601()
    .withMessage('End time must be a valid ISO 8601 date')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { name, description, locations, startTime, endTime } = req.body;
    const userId = req.user.userId;

    // Validate that endTime is after startTime
    if (new Date(endTime) <= new Date(startTime)) {
      return res.status(400).json({
        success: false,
        message: 'End time must be after start time'
      });
    }

    // Create new route
    const route = new Route({
      userId,
      name,
      description,
      locations,
      startTime: new Date(startTime),
      endTime: new Date(endTime)
    });

    await route.save();

    res.status(201).json({
      success: true,
      message: 'Route created successfully',
      route
    });

  } catch (error) {
    console.error('Create route error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error creating route'
    });
  }
});

// @route   GET /api/routes
// @desc    Get user's routes with pagination and filtering
// @access  Private
router.get('/', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    const {
      page = 1,
      limit = 10,
      startDate,
      endDate,
      search
    } = req.query;

    // Build query
    const query = { userId };

    // Date range filter
    if (startDate || endDate) {
      query.startTime = {};
      if (startDate) {
        query.startTime.$gte = new Date(startDate);
      }
      if (endDate) {
        query.startTime.$lte = new Date(endDate);
      }
    }

    // Search filter
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } }
      ];
    }

    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const limitNum = parseInt(limit);

    // Get routes with pagination
    const routes = await Route.find(query)
      .sort({ startTime: -1 })
      .skip(skip)
      .limit(limitNum)
      .select('-locations'); // Exclude detailed locations for list view

    // Get total count for pagination
    const total = await Route.countDocuments(query);

    res.json({
      success: true,
      routes,
      pagination: {
        page: parseInt(page),
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum)
      }
    });

  } catch (error) {
    console.error('Get routes error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting routes'
    });
  }
});

// @route   GET /api/routes/:routeId
// @desc    Get a specific route with full details
// @access  Private
router.get('/:routeId', auth, async (req, res) => {
  try {
    const { routeId } = req.params;
    const userId = req.user.userId;

    const route = await Route.findOne({
      _id: routeId,
      userId
    });

    if (!route) {
      return res.status(404).json({
        success: false,
        message: 'Route not found'
      });
    }

    res.json({
      success: true,
      route
    });

  } catch (error) {
    console.error('Get route error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting route'
    });
  }
});

// @route   PUT /api/routes/:routeId
// @desc    Update a route
// @access  Private
router.put('/:routeId', [
  auth,
  body('name')
    .optional()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Route name must be between 1 and 100 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description cannot exceed 500 characters')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { routeId } = req.params;
    const { name, description } = req.body;
    const userId = req.user.userId;

    const updateData = {};
    if (name) updateData.name = name;
    if (description !== undefined) updateData.description = description;

    const route = await Route.findOneAndUpdate(
      { _id: routeId, userId },
      updateData,
      { new: true, runValidators: true }
    );

    if (!route) {
      return res.status(404).json({
        success: false,
        message: 'Route not found'
      });
    }

    res.json({
      success: true,
      message: 'Route updated successfully',
      route
    });

  } catch (error) {
    console.error('Update route error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error updating route'
    });
  }
});

// @route   DELETE /api/routes/:routeId
// @desc    Delete a route
// @access  Private
router.delete('/:routeId', auth, async (req, res) => {
  try {
    const { routeId } = req.params;
    const userId = req.user.userId;

    const route = await Route.findOneAndDelete({
      _id: routeId,
      userId
    });

    if (!route) {
      return res.status(404).json({
        success: false,
        message: 'Route not found'
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

// @route   GET /api/routes/stats/summary
// @desc    Get user's route statistics summary
// @access  Private
router.get('/stats/summary', auth, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { days = 30 } = req.query;

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - parseInt(days));

    const stats = await Route.aggregate([
      {
        $match: {
          userId: userId,
          startTime: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: null,
          totalRoutes: { $sum: 1 },
          totalDistance: { $sum: '$totalDistance' },
          totalDuration: { $sum: '$totalDuration' },
          averageSpeed: { $avg: '$averageSpeed' },
          maxSpeed: { $max: '$maxSpeed' },
          totalElevationGain: { $sum: '$elevationGain' }
        }
      }
    ]);

    const summary = stats[0] || {
      totalRoutes: 0,
      totalDistance: 0,
      totalDuration: 0,
      averageSpeed: 0,
      maxSpeed: 0,
      totalElevationGain: 0
    };

    // Get recent routes
    const recentRoutes = await Route.find({ userId })
      .sort({ startTime: -1 })
      .limit(5)
      .select('name startTime totalDistance totalDuration');

    res.json({
      success: true,
      summary: {
        ...summary,
        period: `${days} days`,
        recentRoutes
      }
    });

  } catch (error) {
    console.error('Get route stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error getting route statistics'
    });
  }
});

// @route   GET /api/routes/export/:routeId
// @desc    Export route data in GPX format
// @access  Private
router.get('/export/:routeId', auth, async (req, res) => {
  try {
    const { routeId } = req.params;
    const userId = req.user.userId;

    const route = await Route.findOne({
      _id: routeId,
      userId
    });

    if (!route) {
      return res.status(404).json({
        success: false,
        message: 'Route not found'
      });
    }

    // Generate GPX content
    const gpxContent = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Trekr App" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>${route.name}</name>
    <desc>${route.description || ''}</desc>
    <time>${route.startTime.toISOString()}</time>
  </metadata>
  <trk>
    <name>${route.name}</name>
    <desc>${route.description || ''}</desc>
    <trkseg>
${route.locations.map(loc => 
  `      <trkpt lat="${loc.latitude}" lon="${loc.longitude}">
        <time>${loc.timestamp.toISOString()}</time>
        ${loc.altitude ? `<ele>${loc.altitude}</ele>` : ''}
        ${loc.speed ? `<extensions><speed>${loc.speed}</speed></extensions>` : ''}
      </trkpt>`
).join('\n')}
    </trkseg>
  </trk>
</gpx>`;

    res.set({
      'Content-Type': 'application/gpx+xml',
      'Content-Disposition': `attachment; filename="${route.name.replace(/[^a-z0-9]/gi, '_')}.gpx"`
    });

    res.send(gpxContent);

  } catch (error) {
    console.error('Export route error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error exporting route'
    });
  }
});

module.exports = router;