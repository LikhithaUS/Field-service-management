const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const { config } = require('./config/env');
const routes = require('./routes');
const { notFound, errorHandler } = require('./middleware/error');

// Builds the Express app without starting a server, so tests can import it directly.
function createApp() {
  const app = express();

  app.use(helmet());
  app.use(
    cors({
      origin: config.corsOrigins.includes('*') ? true : config.corsOrigins,
    })
  );
  app.use(express.json({ limit: '1mb' }));
  if (!config.isTest) app.use(morgan(config.isProduction ? 'combined' : 'dev'));

  app.get('/api/health', (req, res) => {
    res.json({ success: true, status: 'ok', uptime: process.uptime() });
  });

  app.use('/api', routes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

module.exports = createApp;
