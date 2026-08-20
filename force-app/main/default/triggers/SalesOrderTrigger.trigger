trigger SalesOrderTrigger on Sales_Order__c (before insert, before update, after update) {
    new SalesOrderTriggerHandler().run();
}
