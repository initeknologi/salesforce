/**
 * @description Subscribes to Order_Sync_Event__e platform events and enqueues async processing.
 */
public with sharing class OrderSyncEventHandler {
    public static void handleEvents(List<Order_Sync_Event__e> events) {
        if (events.isEmpty()) {
            return;
        }
        System.enqueueJob(new OrderSyncQueueable(events));
    }
}
