public with sharing class OrderSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private Integer successCount = 0;
    private Integer failureCount = 0;
    private List<String> errorMessages = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Status__c, Account__c, Account__r.BC_Customer_Id__c,
                   Opportunity__c, Order_Date__c, Total_Amount__c,
                   Currency_Code__c, Correlation_Id__c, Description__c,
                   ERP_Order_Id__c
            FROM Sales_Order__c
            WHERE Status__c IN ('Submitted', 'Sync Failed')
            ORDER BY CreatedDate ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Sales_Order__c> scope) {
        Map<Id, ERPIntegrationService.SyncResult> resultsByOrderId =
            new Map<Id, ERPIntegrationService.SyncResult>();
        List<Integration_Log__c> logs = new List<Integration_Log__c>();

        for (Sales_Order__c order : scope) {
            String operation = String.isBlank(order.ERP_Order_Id__c)
                ? ERPIntegrationService.OPERATION_CREATE
                : ERPIntegrationService.OPERATION_UPDATE;

            Long startTime = System.currentTimeMillis();
            ERPIntegrationService.SyncResult result = ERPIntegrationService.syncOrderToERP(
                order, operation, false
            );
            Long duration = System.currentTimeMillis() - startTime;
            resultsByOrderId.put(order.Id, result);
            logs.add(ERPIntegrationService.buildIntegrationLog(
                order.Id,
                operation,
                ERPIntegrationService.buildRequestPayload(order),
                result,
                duration
            ));

            if (result.success) {
                successCount++;
            } else {
                failureCount++;
                errorMessages.add('Order ' + order.Id + ': ' + result.errorMessage);
            }
        }

        // All callouts complete before any DML, avoiding uncommitted-work errors.
        IntegrationLogService.insertLogs(logs);
        SalesOrderService.updateOrdersAfterSync(scope, resultsByOrderId);
    }

    public void finish(Database.BatchableContext bc) {
        Integration_Log__c summaryLog = IntegrationLogService.createLog(
            null,
            'Outbound',
            'Batch Sync',
            IntegrationLogService.LogStatus.SUCCESS,
            'Batch completed: ' + successCount + ' success, ' + failureCount + ' failed',
            String.join(errorMessages, '\n'),
            200,
            null,
            0
        );
        IntegrationLogService.insertLogs(new List<Integration_Log__c>{ summaryLog });
    }
}
