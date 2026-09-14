# Requirements → Solution Mapping

Business scenario: Nordic telecom customer buys battery backup (Sales Cloud) and later raises a warranty case (Service Cloud). Orders sync to Business Central via REST.

| Requirement | Solution | Artifact |
|-------------|----------|----------|
| Customer master with ERP id | Account fields `BC_Customer_Id__c` (unique external id), segment, region | Account metadata, validation rule |
| Win opportunity → sales order | Record-triggered Flow on Closed Won | `Opportunity_Closed_Won_Create_Sales_Order` |
| Idempotent order creation | Invocable Apex checks existing draft | `OpportunityOrderService` |
| Async ERP sync | Platform Event → Queueable chain | `Order_Sync_Event__e`, `OrderSyncQueueable` |
| Retry failed syncs | Batch + manual resubmit from LWC | `OrderSyncBatch`, `erpOrderSyncPanel` |
| Audit trail | Integration log object + correlation id | `Integration_Log__c`, `IntegrationLogService` |
| Inbound status updates | REST resource with API key validation | `OrderSyncRestResource` |
| ERP reconciliation | Scheduled batch compares SF vs ERP list | `OrderReconciliationBatch` |
| Warranty triage | Flow + invocable Apex | `Warranty_Case_Triage`, `WarrantyCaseService` |
| RMA to ERP | Flow on Approved RMA + return order API | `Warranty_RMA_ERP_Sync`, `WarrantyReturnService` |
| Customer 360 view | LWC on Account record page | `customer360Summary` |
| Operations reporting | Native reports + dashboard | `ERP_Integration_Reports` folder |
| Data migration | Bulk import service + sample files | `DataMigrationService`, `scripts/data-migration/` |
| Config without code deploy | Custom metadata settings | `ERP_Integration_Setting__mdt` |
| Secure outbound callouts | Named Credential + Bearer header | `ERP_BC_Mock`, `ERPSettingsProvider` |

## Out of scope (documented)

- Live Business Central tenant (mock ERP used for local dev)
- CPQ, Entitlement enforcement, Omni-Channel routing (see `MANAGED_PACKAGE_NOTES.md`)
- Azure Logic Apps / MuleSoft runtime (see `INTEGRATION_TOPOLOGY.md`)
