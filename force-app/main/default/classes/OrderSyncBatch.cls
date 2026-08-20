/**
 * @description Batch job for bulk ERP synchronization and data migration support.
 *              Processes orders in manageable chunks with callout support.
 */
public class OrderSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private Integer successCount = 0;
    private Integer failureCount = 0;
    private List<String> errorMessages = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Status__c, Account__c, Order_Date__c,
                   Total_Amount__c, Description__c, ERP_Order_Id__c
            FROM Sales_Order__c
            WHERE Status__c IN ('Submitted', 'Sync Failed')
            ORDER BY CreatedDate ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Sales_Order__c> scope) {
        for (Sales_Order__c order : scope) {
            String operation = String.isBlank(order.ERP_Order_Id__c)
                ? ERPIntegrationService.OPERATION_CREATE
                : ERPIntegrationService.OPERATION_UPDATE;

            ERPIntegrationService.SyncResult result = ERPIntegrationService.syncOrderToERP(
                order, operation
            );
            SalesOrderService.updateOrderAfterSync(order.Id, result);

            if (result.success) {
                successCount++;
            } else {
                failureCount++;
                errorMessages.add('Order ' + order.Id + ': ' + result.errorMessage);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        Integration_Log__c summaryLog = IntegrationLogService.createLog(
            null,
            'Outbound',
            'Health Check',
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
