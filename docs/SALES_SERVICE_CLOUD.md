# Sales Cloud & Service Cloud — Design Notes

This integration project uses a **custom `Sales_Order__c` object** to keep the demo focused on ERP sync patterns. In a production Sales Cloud or Service Cloud implementation, the same architecture applies to standard objects and related records.

## Why a Custom Object Here

| Reason | Detail |
|---|---|
| **Scope control** | ERP sync logic is the core deliverable; standard Sales/Service objects add licensing and configuration overhead in a scratch/demo org |
| **Portable pattern** | Service layer, Platform Events, and REST callouts are identical whether the source record is custom or standard |
| **Deployability** | Custom metadata, permission sets, and Apex deploy cleanly without depending on org-specific Sales/Service Cloud setup |

In client projects, the integration layer typically sits **on top of** standard objects — not instead of them.

---

## Sales Cloud Mapping

### Standard object equivalents

| Demo (this repo) | Sales Cloud (production) |
|---|---|
| `Sales_Order__c` | **Order** (post-Opportunity) or custom object fed by **Opportunity** close |
| `Sales_Order__c.Account__c` | **Account** on Order / Opportunity |
| `Sales_Order__c.Status__c` | **Order Status** or Opportunity Stage after Closed Won |
| `Sales_Order__c.Total_Amount__c` | **Order Total** / Opportunity Amount |
| `Sales_Order__c.ERP_Order_Id__c` | External ID field on Order for BC reference |
| Trigger on status change | **Record-Triggered Flow** or Apex trigger on Order / Opportunity |
| `erpOrderSyncPanel` LWC | Record page component on Order or Opportunity layout |

### Recommended Sales Cloud flow

```
Lead → Opportunity → Quote → Order (Closed Won)
                              │
                              ▼
                    Platform Event (Order_Sync_Event__e)
                              │
                              ▼
                    Queueable → REST callout → D365 BC
```

### Best practices (Sales Cloud)

1. **Sync at the right lifecycle point** — Push to ERP when an Order is activated or Opportunity reaches Closed Won, not on every field edit.
2. **Use External ID** — Store BC order number in `ERP_Order_Id__c` (or `Order.ERP_External_Id__c`) for idempotent upserts and inbound callbacks.
3. **Respect CPQ if present** — If Salesforce CPQ is used, sync from **Order** or **Contract** after quote is contracted, not from draft Quote lines.
4. **Don't duplicate CRM data in ERP** — Send only fields BC needs (account ref, line items, ship-to, payment terms); keep Account master in Salesforce.
5. **Opportunity splits & teams** — Sync runs under a dedicated **Integration User** with a Permission Set; avoid running callouts in end-user trigger context.
6. **Governor limits on bulk close** — Use **Batch Apex** (`OrderSyncBatch`) when closing many Opportunities in one operation (e.g. end-of-quarter).
7. **Sharing** — Orders inherit Account sharing; use `with sharing` in services and `UserRecordAccess` checks before manual sync from LWC.

---

## Service Cloud Mapping

Service Cloud integrations often sync **Cases**, **Assets**, or **Entitlements** to ERP for warranty, returns (RMA), or field service billing.

| Service Cloud object | Typical ERP sync use case |
|---|---|
| **Case** | Return merchandise authorization (RMA) → BC Sales Return Order |
| **Case** + **Product2** | Defective product claim → BC item ledger / warranty claim |
| **Asset** | Installed base sync → BC customer item / service contract |
| **Entitlement** | Service level / contract hours → BC service contract |
| **Knowledge** | Not usually synced to ERP; keep in Salesforce for agent self-service |

### Recommended Service Cloud flow

```
Case (Type = Return) → Status = Approved
        │
        ▼
Platform Event (same pattern as Order_Sync_Event__e)
        │
        ▼
Queueable → POST to BC salesReturnOrders endpoint
        │
        ▼
Inbound REST callback → update Case.Status + ERP reference field
```

### Best practices (Service Cloud)

1. **Case Record Types** — Separate sync rules per record type (Return vs Technical vs Billing); avoid one trigger logic for all cases.
2. **Entitlement check before sync** — Validate `Entitlement.Status` and `Remaining_Cases__c` before creating an ERP return order.
3. **Omni-Channel / Assignment** — Don't block case assignment with synchronous callouts; always use async (Platform Event + Queueable).
4. **Integration logs on Case** — Mirror `Integration_Log__c` as a related list on Case for agent visibility without exposing raw payloads to all users.
5. **Knowledge separation** — Knowledge articles stay in Salesforce; link articles to Case via **Case Article** for agent context, not ERP sync.
6. **Email-to-Case** — Cases created from email should not auto-sync until an agent validates and sets Status = Approved.

---

## Shared Patterns (Already in This Repo)

These patterns are cloud-agnostic and apply directly to Sales Cloud and Service Cloud:

| Pattern | Implementation |
|---|---|
| Service layer | `SalesOrderService`, `ERPIntegrationService` |
| One trigger per object | `SalesOrderTrigger` + `SalesOrderTriggerHandler` |
| Event-driven async | `Order_Sync_Event__e` → `OrderSyncQueueable` |
| Bulk / migration | `OrderSyncBatch`, `DataMigrationService` |
| Inbound status updates | `OrderSyncRestResource` |
| Audit trail | `Integration_Log__c` |
| Config per environment | `ERP_Integration_Setting__mdt` |
| Security | Permission Set, `with sharing`, `WITH SECURITY_ENFORCED` |

---

## Extending This Project to Standard Objects

Minimal steps to align with Sales Cloud in a licensed org:

1. Add Apex trigger (or Record-Triggered Flow) on **Order** `after update` when `Status = Activated`.
2. Publish the same `Order_Sync_Event__e` with `Sales_Order_Id__c` replaced by Order Id (or add a new field `Record_Id__c` on the event).
3. Place `erpOrderSyncPanel` on the **Order** Lightning record page.
4. Add **Report Type**: Orders with Integration Logs (once related list exists).
5. Assign `ERP_Integration_Developer` Permission Set to integration user; extend FLS to Order fields.

For Service Cloud, repeat with **Case** and map `OrderSyncRestResource` status values to Case Status picklist values.

---

## Data Model Reference

```
Account (standard)
  └── Sales_Order__c (demo)  →  Order / Case (production)
        └── Integration_Log__c (audit)
```

Relationship and lookup patterns (`Account__c` with `SetNull` on delete) follow the same rules as `Order.AccountId` and `Case.AccountId` in production orgs.
