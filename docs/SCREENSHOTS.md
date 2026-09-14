# Screenshot Guide

All 15 screenshots captured and embedded in [README.md](../README.md).

**Last updated:** 14 September 2026 (DevHub org, ERP Integration Demo app)

## Sales & Service Cloud

| File | Page | Notes |
|---|---|---|
| `11-accounts-list.png` | Accounts list | Nordic Telecom AB; full app nav |
| `12-account-customer-360.png` | Account — Customer 360 | KPIs: opportunities, orders, assets, cases |
| `13-opportunity-closed-won.png` | Opportunity — Closed Won | Sweden 5G Backup Expansion, Nordic Telecom AB |
| `14-case-warranty.png` | Case — warranty | #00001002, battery temperature warning |
| `15-asset-record.png` | Asset — installed equipment | SE-STH-001, GenWatt Diesel 1000kW |

## ERP Integration

| File | Page | Notes |
|---|---|---|
| `01-app-home.png` | App Home | Order Dashboard KPIs (2 orders: 1 synced, 1 failed) |
| `02-sales-orders-list.png` | Sales Orders list | SO-00000 + SO-00002 |
| `03-sales-order-synced.png` | Sales Order — Synced | SO-00000, Nordic Telecom AB, BC-ORD-003 |
| `04-sync-success-toast.png` | Sync to ERP — success | ERP Synchronization panel, status SYNCED |
| `05-erp-health-check.png` | ERP Health Check | SO-00000 record header (Status: Synced) |
| `06-integration-logs-list.png` | Integration Logs list | LOG-851327, LOG-851325 |
| `07-integration-log-detail.png` | Integration Log detail | Correlation ID, Outbound Create Order |
| `08-order-dashboard.png` | Order Dashboard (Home) | Same home page as 01; KPI tiles |
| `09-sales-order-failed.png` | Sales Order — Sync Failed | SO-00002, HTTP 408 error message |
| `10-data-migration-tool.png` | Data Migration (ETL) | JSON import LWC |

## Regenerating screenshots

1. Deploy to a scratch org or DevHub and assign `ERP_Integration_Developer` permission set.
2. Run `scripts/setup-real-case-data.apex` then `scripts/setup-screenshot-data.apex`.
3. Start mock ERP (`node mock-erp/server.js`) and ngrok; point Named Credential `ERP_BC_Mock` at the tunnel URL.
4. Open **ERP Integration Demo** app and capture the pages above.

The app assigns `Account_Customer_360_Record_Page` to Account View so the Customer 360 LWC appears on Nordic Telecom AB.

Toast notifications (sync success, ERP healthy) are ephemeral; panel and record views are used where a static image is needed.
