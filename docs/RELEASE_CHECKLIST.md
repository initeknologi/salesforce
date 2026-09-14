# Release Checklist

Use this for sandbox → UAT → production promotions. The repo uses GitHub Actions and `sf project deploy`; Gearset/Copado follow the same validation gates.

## Pre-deploy

- [ ] Change set or PR reviewed (peer review for production)
- [ ] Apex tests pass locally: `sf apex run test --test-level RunLocalTests --wait 10`
- [ ] Validate deploy to target sandbox: `sf project deploy start --dry-run --test-level RunLocalTests`
- [ ] Integration settings reviewed (`ERP_Integration_Setting__mdt` or target-org overrides)
- [ ] Named Credential endpoint points to correct ERP environment
- [ ] No secrets committed (API keys in org only or CI secrets)

## Deploy

- [ ] Deploy metadata: `sf project deploy start --test-level RunLocalTests`
- [ ] Assign permission set `ERP_Integration_Developer` to integration users
- [ ] Activate Flows if deploy left them inactive
- [ ] Verify Remote Site / Named Credential connectivity

## Post-deploy smoke test

- [ ] ERP health check from `erpOrderSyncPanel` or `ERPIntegrationService.healthCheck()`
- [ ] Create test Opportunity → Closed Won → Sales Order created
- [ ] Submit order → verify Integration Log success
- [ ] Open dashboard `ERP Integration Operations`
- [ ] Warranty Case triage creates Task
- [ ] Approve RMA → return order id populated (with mock ERP running)

## Production-only

- [ ] Schedule reconciliation: `System.schedule('ERP Reconciliation', '0 0 2 * * ?', new OrderReconciliationScheduler());`
- [ ] Monitor Integration Log failed operations
- [ ] Confirm duplicate rule on `BC_Customer_Id__c` active after data migration

## Rollback

- [ ] Revert Git tag / previous package version
- [ ] Deactivate new Flow versions if needed
- [ ] Disable `Is_Active__c` on ERP integration setting to stop outbound callouts
