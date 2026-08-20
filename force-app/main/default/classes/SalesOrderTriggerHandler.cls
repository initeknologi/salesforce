/**
 * @description Trigger handler for Sales_Order__c implementing business logic delegation.
 */
public with sharing class SalesOrderTriggerHandler extends TriggerHandler {
    public override void beforeInsert() {
        SalesOrderService.validateOrders(Trigger.new);
    }

    public override void beforeUpdate() {
        SalesOrderService.validateOrders(Trigger.new);
    }

    public override void afterUpdate() {
        List<Sales_Order__c> ordersToSync = SalesOrderService.getOrdersRequiringSync(
            Trigger.new, (Map<Id, Sales_Order__c>) Trigger.oldMap
        );
        if (!ordersToSync.isEmpty()) {
            SalesOrderService.publishSyncEvents(
                ordersToSync,
                (Map<Id, Sales_Order__c>) Trigger.oldMap
            );
        }
    }
}
