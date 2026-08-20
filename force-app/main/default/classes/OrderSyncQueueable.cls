/**
 * @description Asynchronous processor for ERP order synchronization via Platform Events.
 *              Implements event-driven architecture with retry support.
 */
public class OrderSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<Order_Sync_Event__e> events;

    public OrderSyncQueueable(List<Order_Sync_Event__e> events) {
        this.events = events;
    }

    public void execute(QueueableContext context) {
        Set<Id> orderIds = new Set<Id>();
        Map<Id, String> orderOperations = new Map<Id, String>();
        Map<Id, Integer> retryCounts = new Map<Id, Integer>();

        for (Order_Sync_Event__e evt : events) {
            orderIds.add(evt.Sales_Order_Id__c);
            orderOperations.put(evt.Sales_Order_Id__c, evt.Operation__c);
            retryCounts.put(evt.Sales_Order_Id__c, Integer.valueOf(evt.Retry_Count__c ?? 0));
        }

        SalesOrderService.markOrdersAsSyncing(new List<Id>(orderIds));

        Map<Id, Sales_Order__c> orders = new Map<Id, Sales_Order__c>([
            SELECT Id, Status__c, Account__c, Order_Date__c,
                   Total_Amount__c, Description__c, ERP_Order_Id__c
            FROM Sales_Order__c
            WHERE Id IN :orderIds
        ]);

        List<Sales_Order__c> failedRetries = new List<Sales_Order__c>();

        for (Id orderId : orderIds) {
            Sales_Order__c order = orders.get(orderId);
            if (order == null) {
                continue;
            }

            String operation = determineOperation(order, orderOperations.get(orderId));
            ERPIntegrationService.SyncResult result = ERPIntegrationService.syncOrderToERP(
                order, operation
            );
            SalesOrderService.updateOrderAfterSync(orderId, result);

            if (!result.success) {
                Integer retryCount = retryCounts.get(orderId);
                ERP_Integration_Setting__mdt settings = ERPSettingsProvider.getSettings();
                Integer maxRetries = settings != null
                    ? Integer.valueOf(settings.Max_Retry_Attempts__c ?? 3)
                    : 3;

                if (retryCount < maxRetries) {
                    failedRetries.add(order);
                }
            }
        }

        if (!failedRetries.isEmpty()) {
            List<Order_Sync_Event__e> retryEvents = new List<Order_Sync_Event__e>();
            for (Sales_Order__c order : failedRetries) {
                retryEvents.add(new Order_Sync_Event__e(
                    Sales_Order_Id__c = order.Id,
                    Operation__c = 'CREATE',
                    Retry_Count__c = (retryCounts.get(order.Id) ?? 0) + 1
                ));
            }
            EventBus.publish(retryEvents);
        }
    }

    private String determineOperation(Sales_Order__c order, String eventOperation) {
        if (eventOperation == 'CANCEL') {
            return ERPIntegrationService.OPERATION_CANCEL;
        }
        return String.isBlank(order.ERP_Order_Id__c)
            ? ERPIntegrationService.OPERATION_CREATE
            : ERPIntegrationService.OPERATION_UPDATE;
    }
}
