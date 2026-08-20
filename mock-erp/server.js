/**
 * Mock Dynamics 365 Business Central ERP Server
 *
 * Simulates the BC OData v2.0 API for local Salesforce integration development.
 * Endpoints mirror the real BC API structure used by ERPIntegrationService.cls
 *
 * Start: npm install && npm start
 * Default: http://localhost:3001
 */

const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;
const API_KEY = process.env.API_KEY || 'demo-api-key-local-dev';
const DATA_FILE = path.join(__dirname, 'data', 'orders.json');

app.use(cors());
app.use(express.json());

function loadOrders() {
  try {
    if (fs.existsSync(DATA_FILE)) {
      return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    }
  } catch (err) {
    console.error('Error loading orders:', err.message);
  }
  return [];
}

function saveOrders(orders) {
  const dir = path.dirname(DATA_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(orders, null, 2));
}

function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Bearer token required' });
  }
  const token = authHeader.split(' ')[1];
  if (token !== API_KEY) {
    return res.status(403).json({ error: 'Forbidden: Invalid API key' });
  }
  next();
}

app.get('/api/v2.0/health', authenticate, (req, res) => {
  res.json({
    status: 'healthy',
    service: 'Mock Dynamics 365 Business Central',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/api/v2.0/salesOrders', authenticate, (req, res) => {
  const orders = loadOrders();
  res.json({ value: orders });
});

app.get(/^\/api\/v2\.0\/salesOrders\(([^)]+)\)$/, authenticate, (req, res) => {
  const id = req.params[0];
  const orders = loadOrders();
  const order = orders.find(o => o.id === id);
  if (!order) return res.status(404).json({ error: 'Order not found' });
  res.json(order);
});

app.post('/api/v2.0/salesOrders', authenticate, (req, res) => {
  const orders = loadOrders();
  const newOrder = {
    id: `BC-ORD-${String(orders.length + 1).padStart(3, '0')}`,
    externalId: req.body.externalId,
    customerNumber: req.body.customerNumber,
    orderDate: req.body.orderDate,
    totalAmount: req.body.totalAmount,
    description: req.body.description,
    status: 'Open',
    createdAt: new Date().toISOString()
  };
  orders.push(newOrder);
  saveOrders(orders);
  console.log(`[CREATE] Order ${newOrder.id} from SF externalId=${newOrder.externalId}`);
  res.status(201).json(newOrder);
});

app.patch(/^\/api\/v2\.0\/salesOrders\(([^)]+)\)$/, authenticate, (req, res) => {
  const id = req.params[0];
  const orders = loadOrders();
  const index = orders.findIndex(o => o.id === id);
  if (index === -1) return res.status(404).json({ error: 'Order not found' });

  orders[index] = { ...orders[index], ...req.body, status: 'Released', updatedAt: new Date().toISOString() };
  saveOrders(orders);
  console.log(`[UPDATE] Order ${id}`);
  res.json(orders[index]);
});

app.post(/^\/api\/v2\.0\/salesOrders\(([^)]+)\)\/cancel$/, authenticate, (req, res) => {
  const id = req.params[0];
  const orders = loadOrders();
  const index = orders.findIndex(o => o.id === id);
  if (index === -1) return res.status(404).json({ error: 'Order not found' });

  orders[index].status = 'Cancelled';
  orders[index].cancelledAt = new Date().toISOString();
  saveOrders(orders);
  console.log(`[CANCEL] Order ${id}`);
  res.json(orders[index]);
});

app.post('/api/v2.0/simulate-failure', authenticate, (req, res) => {
  res.status(500).json({ error: 'Simulated ERP failure for testing' });
});

app.listen(PORT, () => {
  console.log('');
  console.log('  Mock Dynamics 365 Business Central ERP Server');
  console.log('  =============================================');
  console.log(`  URL:     http://localhost:${PORT}`);
  console.log(`  API Key: ${API_KEY}`);
  console.log(`  Health:  http://localhost:${PORT}/api/v2.0/health`);
  console.log('');
});
