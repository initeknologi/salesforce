/**
 * @description Domain service for Sales Order business logic.
 *              Separates business rules from trigger and UI layers.
 */
public with sharing class SalesOrderService {
    public static final Set<String> SYNCABLE_STATUSES = new Set<String>{
        'Submitted', 'Sync Failed'
    };

    /**
     * @description Validates sales orders before insert/update.
     */
    public static void validateOrders(List<Sales_Order__c> orders) {
        for (Sales_Order__c order : orders) {
            if (order.Total_Amount__c != null && order.Total_Amount__c < 0) {
                order.Total_Amount__c.addError('Total Amount cannot be negative.');
            }
            if (order.Order_Date__c != null && order.Order_Date__c > Date.today()) {
                order.Order_Date__c.addError('Order Date cannot be in the future.');
            }
        }
    }

    /**
     * @description Identifies orders that need ERP synchronization after status change.
     */
    public static List<Sales_Order__c> getOrdersRequiringSync(
        List<Sales_Order__c> newOrders,
        Map<Id, Sales_Order__c> oldMap
    ) {
        List<Sales_Order__c> ordersToSync = new List<Sales_Order__c>();
        for (Sales_Order__c order : newOrders) {
            Sales_Order__c oldOrder = oldMap.get(order.Id);
            if (oldOrder == null) {
                continue;
            }
            Boolean statusChanged = order.Status__c != oldOrder.Status__c;
            Boolean needsSync = SYNCABLE_STATUSES.contains(order.Status__c);
            if (statusChanged && needsSync) {
                ordersToSync.add(order);
            }
        }
        return ordersToSync;
    }

    /**
     * @description Publishes platform events for asynchronous ERP sync.
     */
    public static void publishSyncEvents(List<Sales_Order__c> orders, String operation) {
        List<Order_Sync_Event__e> events = new List<Order_Sync_Event__e>();
        for (Sales_Order__c order : orders) {
            events.add(new Order_Sync_Event__e(
                Sales_Order_Id__c = order.Id,
                Operation__c = operation,
                Retry_Count__c = 0
            ));
        }
        if (!events.isEmpty()) {
            EventBus.publish(events);
        }
    }

    /**
     * @description Updates order status after sync attempt.
     */
    public static void updateOrderAfterSync(
        Id orderId,
        ERPIntegrationService.SyncResult result
    ) {
        Sales_Order__c order = new Sales_Order__c(
            Id = orderId,
            Last_Sync_Date__c = System.now()
        );

        if (result.success) {
            order.Status__c = 'Synced';
            order.ERP_Order_Id__c = result.erpOrderId;
            order.Sync_Error_Message__c = null;
        } else {
            order.Status__c = 'Sync Failed';
            order.Sync_Error_Message__c = result.errorMessage;
        }

        update order;
    }

    /**
     * @description Marks orders as Syncing before async processing begins.
     */
    public static void markOrdersAsSyncing(List<Id> orderIds) {
        List<Sales_Order__c> orders = new List<Sales_Order__c>();
        for (Id orderId : orderIds) {
            orders.add(new Sales_Order__c(
                Id = orderId,
                Status__c = 'Syncing'
            ));
        }
        if (!orders.isEmpty()) {
            update orders;
        }
    }

    /**
     * @description Retrieves order summary statistics for dashboard LWC.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getOrderSummary() {
        Map<String, Integer> summary = new Map<String, Integer>{
            'total' => 0, 'draft' => 0, 'submitted' => 0,
            'synced' => 0, 'syncFailed' => 0, 'syncing' => 0
        };

        for (AggregateResult ar : [
            SELECT Status__c status, COUNT(Id) cnt
            FROM Sales_Order__c
            GROUP BY Status__c
        ]) {
            String status = (String) ar.get('status');
            Integer count = (Integer) ar.get('cnt');
            summary.put('total', summary.get('total') + count);

            if (status == 'Draft') summary.put('draft', count);
            else if (status == 'Submitted') summary.put('submitted', count);
            else if (status == 'Synced') summary.put('synced', count);
            else if (status == 'Sync Failed') summary.put('syncFailed', count);
            else if (status == 'Syncing') summary.put('syncing', count);
        }
        return summary;
    }

    @AuraEnabled
    public static String checkERPHealth() {
        Boolean healthy = ERPIntegrationService.healthCheck();
        return healthy ? 'ERP connection is healthy.' : 'ERP connection failed. Check tunnel and mock server.';
    }

    /**
     * @description Manually triggers ERP sync for a single order from LWC.
     */
    @AuraEnabled
    public static String syncOrderToERP(Id orderId) {
        List<Sales_Order__c> orders = [
            SELECT Id, Status__c, Account__c, Order_Date__c,
                   Total_Amount__c, Description__c, ERP_Order_Id__c
            FROM Sales_Order__c
            WHERE Id = :orderId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new AuraHandledException('Sales Order not found.');
        }

        Sales_Order__c order = orders[0];
        if (!SYNCABLE_STATUSES.contains(order.Status__c) && order.Status__c != 'Synced') {
            throw new AuraHandledException(
                'Order must be in Submitted or Sync Failed status to sync.'
            );
        }

        String operation = String.isBlank(order.ERP_Order_Id__c)
            ? ERPIntegrationService.OPERATION_CREATE
            : ERPIntegrationService.OPERATION_UPDATE;

        ERPIntegrationService.SyncResult result = ERPIntegrationService.syncOrderToERP(
            order, operation
        );
        SalesOrderService.updateOrderAfterSync(orderId, result);

        return result.success ? 'Order synced successfully.' : result.errorMessage;
    }
}
