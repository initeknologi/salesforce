# Design Decisions

Technical rationale behind key architecture choices in this project. Use this as reference when presenting the solution to stakeholders or technical reviewers.

---

## 1. Platform Events instead of synchronous Apex callouts

**Problem:** Salesforce does not allow HTTP callouts in the same transaction as DML that triggers them. A trigger that updates `Sales_Order__c` and immediately calls the ERP API will throw `System.CalloutException: You have uncommitted work pending`.

**Decision:** When order status changes to a syncable value, the trigger publishes `Order_Sync_Event__e`. A separate subscriber (`OrderSyncEventHandler`) enqueues `OrderSyncQueueable`, which performs the callout in a new transaction.

**Trade-offs:**
- Adds latency (~1–3 seconds) vs synchronous sync
- Gains reliability, retry support, and governor limit headroom
- Aligns with event-driven integration patterns used in enterprise ERP projects

**Alternative considered:** `@future(callout=true)` — rejected because it cannot be chained easily and is harder to test and monitor than Queueable.

---

## 2. Custom Metadata for ERP configuration

**Problem:** Integration endpoints, API keys, timeouts, and retry counts differ per environment (Sandbox, UAT, Production).

**Decision:** Store all settings in `ERP_Integration_Setting__mdt`, accessed via cached `ERPSettingsProvider`.

**Why not Custom Settings?**
- Custom Metadata deploys with the package — no manual post-deploy configuration
- Supports multiple records (one per environment)
- Cacheable without SOQL in hot paths

**Production path:** Replace API key field with **Named Credentials** + **External Credentials**; keep Custom Metadata for non-secret settings (timeout, retry count).

---

## 3. Service layer pattern

**Problem:** Business logic scattered across triggers, LWC controllers, and batch jobs becomes untestable and duplicated.

**Decision:**
- `SalesOrderService` — domain logic, validation, `@AuraEnabled` methods for LWC
- `ERPIntegrationService` — HTTP callouts only
- `IntegrationLogService` — audit logging only
- Triggers delegate to handlers; handlers call services

**Benefit:** Each layer has a single responsibility. Unit tests mock at the service boundary. Same sync logic runs from LWC, trigger, batch, and REST callback.

---

## 4. TriggerHandler framework

**Problem:** Multiple triggers on one object, recursion loops, and bulkification violations are common in mature orgs.

**Decision:** One trigger per object (`SalesOrderTrigger`) delegates to `SalesOrderTriggerHandler extends TriggerHandler`. The base class provides recursion counting and bypass support for tests.

**Benefit:** Test isolation via `TriggerHandler.bypass('SalesOrderTriggerHandler')` and consistent bulk-safe patterns.

---

## 5. Permission Sets over Profile modifications

**Problem:** Editing standard Profiles affects all users assigned to that profile, including users unrelated to ERP integration.

**Decision:** `ERP_Integration_Developer` Permission Set grants object, field, class, and tab access. Assign only to integration users and developers.

**Production:** Create a dedicated **Integration User** with this permission set; never run callouts under end-user context.

---

## 6. Integration_Log__c audit trail

**Problem:** When ERP sync fails in production, teams need request/response payloads, HTTP status, and duration to perform root-cause analysis.

**Decision:** Every outbound and inbound API call creates an `Integration_Log__c` record via `IntegrationLogService`. Logs are read-only for most users (create via Apex only).

**Note:** In orgs with storage limits, use `Database.insert(logs, false)` so a failed log insert does not block the sync itself.

---

## 7. Custom object vs standard Order

**Problem:** This project focuses on ERP sync patterns, not full Sales Cloud configuration (CPQ, price books, etc.).

**Decision:** Use `Sales_Order__c` as a focused integration domain object. Map to standard **Order** or **Opportunity** in production — see [SALES_SERVICE_CLOUD.md](SALES_SERVICE_CLOUD.md).

---

## 8. Mock ERP server for local development

**Problem:** Salesforce cloud orgs cannot call `localhost`. Developers need a realistic BC OData v2.0 endpoint for testing.

**Decision:** Node.js mock server (`mock-erp/server.js`) on port 3001, exposed via ngrok tunnel for cloud org callouts.

**Production:** Replace with Azure Logic Apps, MuleSoft, or direct BC tenant OData API.

---

## 9. CI/CD with GitHub Actions

**Problem:** Metadata changes must be validated before promotion to UAT/Production.

**Decision:** On every push/PR — create scratch org, deploy, run Apex tests with coverage, lint LWC.

**Production path:** Add promotion stages (Sandbox → UAT → Prod) and integrate Gearset or Copado if required by the client.

---

## 10. Named Credential support

**Decision:** Optional `Named_Credential__c` field on Custom Metadata. When set, outbound callouts use `callout:ERP_Integration` instead of Remote Site URLs.

**Rationale:** Named Credentials are the Salesforce standard for production endpoint and authentication management.

---

## 11. Inbound REST API authentication

**Decision:** `OrderSyncRestResource` validates `Authorization: Bearer <API_Key>` on every POST callback.

**Rationale:** Prevents unauthorized systems from updating Salesforce order status.
