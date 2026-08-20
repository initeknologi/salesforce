# Architecture Decision Records

## ADR-001: Service Layer Pattern

**Decision**: Separate business logic into service classes (`SalesOrderService`, `ERPIntegrationService`) rather than placing logic directly in triggers or LWC controllers.

**Rationale**: Improves testability, reusability across triggers/LWC/batch/REST, and follows Salesforce enterprise patterns.

## ADR-002: Platform Events for Async Integration

**Decision**: Use `Order_Sync_Event__e` Platform Events to decouple order status changes from ERP callouts.

**Rationale**: 
- Avoids mixed DML/callout governor limit issues
- Enables retry without re-triggering record updates
- Supports event-driven architecture as required by the job spec

## ADR-003: Custom Metadata for Configuration

**Decision**: Store ERP endpoint URL, API key, timeout, and retry settings in `ERP_Integration_Setting__mdt`.

**Rationale**: Deployable across Sandbox/UAT/Production without manual configuration. Cached via `ERPSettingsProvider` for performance.

## ADR-004: Trigger Handler Framework

**Decision**: Implement virtual `TriggerHandler` base class with recursion control and bypass support.

**Rationale**: Industry-standard pattern (Kevin O'Hara framework). Prevents infinite loops and enables test isolation.

## ADR-005: Integration Audit Logging

**Decision**: Every API call (inbound and outbound) creates an `Integration_Log__c` record with request/response payloads.

**Rationale**: Required for troubleshooting, compliance, and root-cause analysis in enterprise integrations.

## ADR-006: Permission Sets over Profile Changes

**Decision**: Use `ERP_Integration_Developer` Permission Set instead of modifying standard profiles.

**Rationale**: Salesforce best practice — modular, assignable, and doesn't affect unrelated users.
