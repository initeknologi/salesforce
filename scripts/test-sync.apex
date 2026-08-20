Boolean healthy = ERPIntegrationService.healthCheck();
System.debug('HEALTH_CHECK=' + healthy);

Id orderId = 'a01bm00002hbNjqAAE';

Sales_Order__c order = [
    SELECT Id, Name, Status__c, Account__c, Order_Date__c,
           Total_Amount__c, Description__c, ERP_Order_Id__c
    FROM Sales_Order__c
    WHERE Id = :orderId
    LIMIT 1
];

order.Status__c = 'Submitted';
order.Sync_Error_Message__c = null;
order.ERP_Order_Id__c = null;
update order;

String message = SalesOrderService.syncOrderToERP(orderId);

Sales_Order__c updated = [
    SELECT Id, Name, Status__c, ERP_Order_Id__c, Sync_Error_Message__c, Last_Sync_Date__c
    FROM Sales_Order__c
    WHERE Id = :orderId
    LIMIT 1
];

System.debug('SYNC_MESSAGE=' + message);
System.debug('FINAL_STATUS=' + updated.Status__c);
System.debug('ERP_ORDER_ID=' + updated.ERP_Order_Id__c);
System.debug('SYNC_ERROR=' + updated.Sync_Error_Message__c);
