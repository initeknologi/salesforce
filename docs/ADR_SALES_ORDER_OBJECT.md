# ADR: Custom Sales Order vs Standard Order

## Status

Accepted — reference implementation (2025).

## Context

The demo integrates Salesforce with Microsoft Dynamics 365 Business Central (BC). Closed Won opportunities must produce an ERP-ready sales order with correlation ids, sync status, and integration logs.

Standard Salesforce objects include Order and Order Product. CPQ Quote-to-Order is common in enterprise Sales Cloud but adds licensing and package dependencies.

## Decision

Use custom object `Sales_Order__c` as the integration boundary record.

## Rationale

1. **Scope control** — The project focuses on ERP sync patterns, not full quote-to-cash.
2. **Explicit contract** — Fields such as `Correlation_Id__c`, `ERP_Order_Id__c`, and `Currency_Code__c` map directly to BC OData payloads.
3. **Testability** — Services and batch jobs operate on a narrow object with no dependency on Order activation or price book setup.
4. **Production path** — In a live org, the same service layer can target standard Order or a middleware canonical model without changing event-driven sync.

## Consequences

- Reporting uses custom report types on `Sales_Order__c` alongside native Opportunity reports.
- UI uses custom tabs and record pages instead of standard Order layouts.
- Opportunity linkage is via lookup `Opportunity__c` and Flow on Closed Won.

## Alternatives considered

| Option | Why not chosen for this repo |
|--------|------------------------------|
| Standard Order | Requires more baseline commerce setup for a focused integration demo |
| Salesforce CPQ | License and package overhead beyond integration scope |
| Middleware-only storage | Loses Salesforce operational visibility for support teams |

## Review

Revisit when CPQ or Order Management is in scope for the target org.
