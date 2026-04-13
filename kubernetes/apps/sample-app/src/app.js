const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    service: 'sample-app',
    version: process.env.APP_VERSION || '1.0.0',
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
    message: 'Platform MVP Sample Application'
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

app.get('/ready', (req, res) => {
  res.status(200).json({ status: 'ready' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Sample app listening on port ${PORT}`);
});
