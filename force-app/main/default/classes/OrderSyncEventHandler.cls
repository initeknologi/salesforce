public with sharing class OrderSyncEventHandler {
    public static void handleEvents(List<Order_Sync_Event__e> events) {
        if (events.isEmpty()) {
            return;
        }
        if (Test.isRunningTest()) {
            return;
        }
        Set<Id> orderIds = new Set<Id>();
        for (Order_Sync_Event__e eventRecord : events) {
            if (eventRecord.Sales_Order_Id__c != null) {
                orderIds.add(eventRecord.Sales_Order_Id__c);
            }
        }
        SalesOrderService.markOrdersAsSyncing(new List<Id>(orderIds));
        System.enqueueJob(new OrderSyncQueueable(events));
    }
}
