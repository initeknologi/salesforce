public with sharing class SalesOrderService {
    public static final Set<String> SYNCABLE_STATUSES = new Set<String>{
        'Submitted', 'Sync Failed'
    };

    public static void validateOrders(List<Sales_Order__c> orders) {
        for (Sales_Order__c order : orders) {
            if (String.isBlank(order.Currency_Code__c)) {
                order.Currency_Code__c = 'SEK';
            }
            if (String.isBlank(order.Correlation_Id__c)) {
                order.Correlation_Id__c =
                    'SF-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128));
            }
            if (order.Total_Amount__c != null && order.Total_Amount__c < 0) {
                order.Total_Amount__c.addError('Total Amount cannot be negative.');
            }
            if (order.Order_Date__c != null && order.Order_Date__c > Date.today()) {
                order.Order_Date__c.addError('Order Date cannot be in the future.');
            }
            if (SYNCABLE_STATUSES.contains(order.Status__c) &&
                (order.Account__c == null || order.Total_Amount__c == null ||
                 order.Total_Amount__c <= 0)) {
                order.addError(
                    'Submitted orders require an Account and positive Total Amount.'
                );
            }
        }
    }

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
            // Failed results are retried by Queueable with an incremented count.
            // Republishing from Sync Failed would reset the count and loop forever.
            Boolean needsSync = order.Status__c == 'Submitted' ||
                (order.Status__c == 'Cancelled' &&
                 String.isNotBlank(order.ERP_Order_Id__c));
            if (statusChanged && needsSync) {
                ordersToSync.add(order);
            }
        }
        return ordersToSync;
    }

    public static void publishSyncEvents(
        List<Sales_Order__c> orders,
        Map<Id, Sales_Order__c> oldMap
    ) {
        List<Order_Sync_Event__e> events = new List<Order_Sync_Event__e>();
        for (Sales_Order__c order : orders) {
            Sales_Order__c oldOrder = oldMap != null ? oldMap.get(order.Id) : null;
            events.add(new Order_Sync_Event__e(
                Sales_Order_Id__c = order.Id,
                Operation__c = resolveEventOperation(order, oldOrder),
                Retry_Count__c = 0
            ));
        }
        if (!events.isEmpty()) {
            EventBus.publish(events);
        }
    }

    public static String resolveEventOperation(
        Sales_Order__c order,
        Sales_Order__c oldOrder
    ) {
        if (order.Status__c == 'Cancelled') {
            return 'CANCEL';
        }
        return String.isBlank(order.ERP_Order_Id__c) ? 'CREATE' : 'UPDATE';
    }

    public static void updateOrderAfterSync(
        Id orderId,
        ERPIntegrationService.SyncResult result
    ) {
        Sales_Order__c currentOrder = [
            SELECT Opportunity__c
            FROM Sales_Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];
        updateOrdersAfterSync(
            new List<Sales_Order__c>{ currentOrder },
            new Map<Id, ERPIntegrationService.SyncResult>{ orderId => result }
        );
    }

    public static void updateOrdersAfterSync(
        List<Sales_Order__c> sourceOrders,
        Map<Id, ERPIntegrationService.SyncResult> resultsByOrderId
    ) {
        List<Sales_Order__c> orderUpdates = new List<Sales_Order__c>();
        Map<Id, Opportunity> opportunityUpdates = new Map<Id, Opportunity>();

        for (Sales_Order__c sourceOrder : sourceOrders) {
            ERPIntegrationService.SyncResult result =
                resultsByOrderId.get(sourceOrder.Id);
            if (result == null) {
                continue;
            }

            Sales_Order__c orderUpdate = new Sales_Order__c(
                Id = sourceOrder.Id,
                Last_Sync_Date__c = System.now(),
                Status__c = result.success ? 'Synced' : 'Sync Failed',
                Sync_Error_Message__c = result.success ? null : result.errorMessage
            );
            if (result.success && String.isNotBlank(result.erpOrderId)) {
                orderUpdate.ERP_Order_Id__c = result.erpOrderId;
            }
            orderUpdates.add(orderUpdate);

            if (sourceOrder.Opportunity__c != null) {
                opportunityUpdates.put(
                    sourceOrder.Opportunity__c,
                    new Opportunity(
                        Id = sourceOrder.Opportunity__c,
                        ERP_Sync_Status__c = result.success ? 'Synced' : 'Failed'
                    )
                );
            }
        }

        if (!orderUpdates.isEmpty()) {
            update orderUpdates;
        }
        if (!opportunityUpdates.isEmpty()) {
            update opportunityUpdates.values();
        }
    }

    public static void markOrdersAsSyncing(List<Id> orderIds) {
        Set<Id> opportunityIds = new Set<Id>();
        for (Sales_Order__c order : [
            SELECT Opportunity__c
            FROM Sales_Order__c
            WHERE Id IN :orderIds
        ]) {
            if (order.Opportunity__c != null) {
                opportunityIds.add(order.Opportunity__c);
            }
        }

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
        if (!opportunityIds.isEmpty()) {
            List<Opportunity> opportunities = new List<Opportunity>();
            for (Id opportunityId : opportunityIds) {
                opportunities.add(new Opportunity(
                    Id = opportunityId,
                    ERP_Sync_Status__c = 'Processing'
                ));
            }
            update opportunities;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getOrderSummary() {
        if (!Schema.sObjectType.Sales_Order__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Sales Orders.');
        }

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

    @AuraEnabled
    public static String syncOrderToERP(Id orderId) {
        List<Sales_Order__c> orders = [
            SELECT Id, Status__c, Account__c, Account__r.BC_Customer_Id__c,
                   Opportunity__c, Order_Date__c, Total_Amount__c,
                   Currency_Code__c, Correlation_Id__c, Description__c,
                   ERP_Order_Id__c
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
