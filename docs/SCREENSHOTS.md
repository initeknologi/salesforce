# Screenshot Guide

Add screenshots to `docs/images/` and reference them from the README. Use PNG format, 1440px wide or full browser width, and hide personal/sensitive data before committing.

## Required (minimum 6)

| # | Page | What to capture | Filename suggestion |
|---|---|---|---|
| 1 | **App Home** | `ERP Integration Demo` app with `orderDashboard` LWC showing metric cards (Draft, Submitted, Synced, Sync Failed) | `01-app-home-dashboard.png` |
| 2 | **Sales Orders — List View** | Tab `Sales Orders`, list view `All Sales Orders`, several records with mixed statuses | `02-sales-orders-list.png` |
| 3 | **Sales Order — Synced** | Record page with Status = **Synced**, ERP Order Id populated, `erpOrderSyncPanel` showing green Synced badge | `03-sales-order-synced.png` |
| 4 | **Sales Order — Sync panel action** | Same page with Sync / Health Check buttons visible (before or after click, showing toast) | `04-sync-panel-actions.png` |
| 5 | **Integration Logs — List View** | Tab `Integration Logs`, entries with Success/Failed status, HTTP codes | `05-integration-logs-list.png` |
| 6 | **Integration Log — Detail** | Single log record: Operation, Direction, Request/Response payload, Duration | `06-integration-log-detail.png` |

## Recommended (strengthens the story)

| # | Page | What to capture | Filename suggestion |
|---|---|---|---|
| 7 | **Sales Order — Sync Failed** | Record with Status = Sync Failed and error message visible | `07-sales-order-failed.png` |
| 8 | **Account related** | Standard Account record with related Sales Orders | `08-account-with-orders.png` |
| 9 | **Data Migration Tool** | Lightning App Builder tab or App Page with `dataMigrationTool` LWC (add component to a tab first) | `09-data-migration-tool.png` |
| 10 | **Apex Test Results** | Developer Console or CLI output showing tests passed + code coverage | `10-apex-test-results.png` |
| 11 | **Setup — Permission Set** | `ERP Integration Developer` permission set assigned to your user | `11-permission-set.png` |
| 12 | **Setup — Custom Metadata** | `ERP Integration Setting` → Local Development record (blur API key if shown) | `12-custom-metadata.png` |

## Optional (technical depth for technical interviewers)

| # | What to capture | Filename suggestion |
|---|---|---|
| 13 | Mock ERP terminal — `npm start` running on port 3001 | `13-mock-erp-terminal.png` |
| 14 | ngrok tunnel active pointing to localhost:3001 | `14-ngrok-tunnel.png` |
| 15 | GitHub repo page or Actions CI workflow (green check) | `15-github-ci.png` |

## How to add Data Migration Tool tab (for screenshot #9)

1. Setup → Tabs → New → Lightning Component Tab → select `dataMigrationTool`.
2. Edit `ERP Integration Demo` app → add the new tab.
3. Open the tab and capture the import UI.

## Tips

- Use Lightning Experience (not Classic).
- Zoom browser to 100%; crop browser chrome if needed.
- Show realistic data (company names like "Acme Corporation", amounts, dates).
- Blur or redact: org Id, username, ngrok URL, API keys.
- After adding images, update the Screenshots section in `README.md`.
