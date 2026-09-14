# Global Battery Sales and Service Architecture

## Business outcome

This implementation gives sales, operations, finance, and service teams one traceable process:

1. Sales qualifies an Account and Opportunity in Sales Cloud.
2. Closing the Opportunity as won creates one draft integration order.
3. Operations reviews and submits the order.
4. Salesforce publishes a Platform Event and performs the ERP callout asynchronously.
5. Business Central returns an order identifier; Salesforce records the result and audit log.
6. Service agents relate installed battery Assets and warranty Cases to the same Account.
7. Warranty automation prioritizes the Case and creates one diagnostic follow-up Task.

## Data ownership

- Salesforce owns customer engagement, pipeline, installed-asset context, Cases, and Tasks.
- Business Central owns fulfillment and ERP order processing.
- `BC_Customer_Id__c`, `ERP_Order_Id__c`, and `BC_Return_Order_Id__c` store system-of-record identifiers.
- `Correlation_Id__c` is the stable idempotency and tracing key for an outbound order.
- `Sales_Order__c.Opportunity__c` and `Opportunity.Generated_Sales_Order__c` provide two-way navigation.

## Sales automation

`Opportunity_Closed_Won_Create_Sales_Order` runs after an Opportunity changes to Closed Won. Flow owns orchestration and invokes `OpportunityOrderService` for bulk-safe logic.

The service:

- validates Closed Won, Account, and positive Amount;
- checks for an existing order by Opportunity;
- creates one draft order with a unique correlation ID;
- sets Opportunity ERP status to Ready;
- returns the existing order when invoked again.

The Flow fault path creates a high-priority Task instead of silently losing an automation failure.

## ERP integration

Changing an order to Submitted publishes `Order_Sync_Event__e`. The subscriber marks the transaction as Processing and starts `OrderSyncQueueable`.

Each Queueable processes one order before chaining the remainder. This design prevents a DML operation from occurring between callouts when Salesforce delivers several Platform Events together.

For scheduled bulk synchronization, `OrderSyncBatch` completes all callouts in its scope before inserting logs and updating records in bulk.

The mock Business Central API treats `externalId` as an idempotency key. A repeated POST returns the original ERP order instead of creating a duplicate.

Production authentication should use Named Credentials and External Credentials. No production secret or tunnel URL belongs in source control.

## Service automation

Cases use the standard Account and Asset relationships. `Warranty_Case_Triage` invokes `WarrantyCaseService` when a Case enters the Warranty process.

The service:

- raises priority to High when an installed Asset is present;
- sets RMA status to Requested;
- initializes integration status;
- creates one open diagnostic Task;
- returns the existing Task on repeated invocation.

The Flow fault path creates an owner-visible failure Task.

## Security and governance

- Apex services use `with sharing`.
- UI queries use user-mode SOQL or security-enforced queries.
- Create and update operations strip inaccessible fields before DML where user context is required.
- A Permission Set grants object, field, Apex class, tab, and application access.
- Unique External ID fields enforce duplicate prevention at the data layer.
- Integration Logs provide request, response, status, duration, and error evidence.
- Configuration is stored in Custom Metadata; secrets should move to External Credentials for production.

## Operational views

- `customer360Summary` shows open Opportunities, Sales Orders, installed Assets, open Cases, and failed integrations on Account records.
- `orderDashboard` shows order lifecycle and failure counts.
- Integration Logs support root-cause analysis and retry decisions.

## Deployment path

Promote source through Sandbox, UAT, and Production using pull requests and CI validation. Run Apex tests, validate the deployment, obtain business approval in UAT, then deploy the same versioned metadata to Production.

## Current boundary

The repository implements outbound sales-order synchronization and warranty triage. A production program would additionally connect approved RMAs to the Business Central sales-return API, configure Entitlement and Milestone policies, and replace the local ERP server with the approved Azure or MuleSoft integration layer.
