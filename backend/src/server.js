const { config, assertRequired } = require('./config/env');
const { connectDB, disconnectDB } = require('./config/db');
const createApp = require('./app');

async function start() {
  assertRequired();
  await connectDB(config.mongoUri);

  const app = createApp();
  const server = app.listen(config.port, () => {
    console.log(`ServiceHub API running on http://localhost:${config.port} (${config.env})`);
  });

  const shutdown = async (signal) => {
    console.log(`${signal} received, shutting down...`);
    server.close(async () => {
      await disconnectDB();
      process.exit(0);
    });
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

start().catch((err) => {
  console.error('Failed to start server:', err.message);
  process.exit(1);
});
