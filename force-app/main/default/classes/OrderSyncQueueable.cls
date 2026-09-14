public with sharing class OrderSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<Order_Sync_Event__e> events;

    public OrderSyncQueueable(List<Order_Sync_Event__e> events) {
        this.events = events == null
            ? new List<Order_Sync_Event__e>()
            : new List<Order_Sync_Event__e>(events);
    }

    public void execute(QueueableContext context) {
        if (events.isEmpty()) {
            return;
        }

        // Process one order per Queueable. ERPIntegrationService persists a log
        // after each callout, so chaining prevents DML-before-callout failures
        // when a platform-event batch contains multiple orders.
        Order_Sync_Event__e eventToProcess = events.remove(0);
        Id orderId = eventToProcess.Sales_Order_Id__c;
        List<Sales_Order__c> orders = [
            SELECT Id, Status__c, Account__c, Account__r.BC_Customer_Id__c,
                   Opportunity__c, Order_Date__c, Total_Amount__c,
                   Currency_Code__c, Correlation_Id__c, Description__c,
                   ERP_Order_Id__c
            FROM Sales_Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (!orders.isEmpty()) {
            Sales_Order__c order = orders[0];
            String operation = determineOperation(order, eventToProcess.Operation__c);

            if (!shouldSkipSync(order, operation)) {
                ERPIntegrationService.SyncResult result =
                    ERPIntegrationService.syncOrderToERP(order, operation);
                SalesOrderService.updateOrderAfterSync(orderId, result);

                Integer retryCount = Integer.valueOf(eventToProcess.Retry_Count__c ?? 0);
                ERP_Integration_Setting__mdt settings = ERPSettingsProvider.getSettings();
                Integer maxRetries = settings != null
                    ? Integer.valueOf(settings.Max_Retry_Attempts__c ?? 3)
                    : 3;

                if (!result.success && retryCount < maxRetries &&
                    !Test.isRunningTest()) {
                    EventBus.publish(new Order_Sync_Event__e(
                        Sales_Order_Id__c = order.Id,
                        Operation__c = eventToProcess.Operation__c,
                        Retry_Count__c = retryCount + 1
                    ));
                }
            }
        }

        if (!events.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new OrderSyncQueueable(events));
        }
    }

    @TestVisible
    private static Boolean shouldSkipSync(Sales_Order__c order, String operation) {
        if (order.Status__c == 'Synced'
            && operation == ERPIntegrationService.OPERATION_CREATE
            && String.isNotBlank(order.ERP_Order_Id__c)) {
            return true;
        }
        return false;
    }

    private String determineOperation(Sales_Order__c order, String eventOperation) {
        if (eventOperation == 'CANCEL') {
            return ERPIntegrationService.OPERATION_CANCEL;
        }
        if (eventOperation == 'UPDATE' || String.isNotBlank(order.ERP_Order_Id__c)) {
            return ERPIntegrationService.OPERATION_UPDATE;
        }
        return ERPIntegrationService.OPERATION_CREATE;
    }
}
