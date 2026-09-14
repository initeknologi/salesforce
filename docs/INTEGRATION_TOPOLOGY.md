# Integration Topology

## Current implementation (repo)

```
Salesforce (Apex/LWC/Flow)
    │  HTTPS + Bearer token / Named Credential
    ▼
Mock BC OData API (local Node.js)
```

Outbound: `ERPIntegrationService` → POST/PATCH `/salesOrders`, POST `/returnOrders`  
Inbound: `OrderSyncRestResource` ← ERP status callbacks  
Async: Platform Event → Queueable → optional Batch retry  
Reconciliation: `OrderReconciliationBatch` ← GET `/salesOrders`

## Typical production pattern

```
Salesforce
    │  Platform Events / REST
    ▼
Azure API Management or MuleSoft
    │  Transform, throttle, secrets
    ▼
Business Central (OData v2.0)
```

### Why middleware

- Centralize OAuth/token refresh for BC
- Rate limiting and circuit breaking
- Schema mapping without Apex changes
- Dual write to data warehouse or monitoring

### SOAP

Legacy ERP endpoints may expose SOAP for status or master data. This repo includes `ErpStatusSoapApi` as a minimal SOAP ping; primary order flow uses REST/OData consistent with BC.

## Environments

| Tier | Purpose |
|------|---------|
| Developer scratch / sandbox | Feature development, mock ERP |
| UAT | Business validation, BC test company |
| Production | Live BC company, Named Credential per env |

Configuration is externalized in `ERP_Integration_Setting__mdt` per org.

## DevOps alignment

GitHub Actions runs LWC lint and optional `sf project deploy --dry-run`. Gearset and Copado provide the same steps: validate tests, compare metadata, promote between branches mapped to sandboxes.
