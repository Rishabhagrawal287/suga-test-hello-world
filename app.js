const express = require('express');
const app = express();
const port = process.env.PORT || 3005;

app.get('/', (req, res) => {
  res.send('Hello World V2 - Zero-Downtime Test!');
});

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.get('/slow', async (req, res) => {
  await new Promise(resolve => setTimeout(resolve, 5000));
  res.send('Slow response completed');
});

let requestCount = 0;
app.use((req, res, next) => {
  requestCount++;
  console.log(`Request #${requestCount}: ${req.method} ${req.path}`);
  next();
});

app.get('/stats', (req, res) => {
  res.json({ 
    requests: requestCount,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: '1.0.0'
  });
});

app.listen(port, () => {
  console.log(`App running on port ${port}`);
});