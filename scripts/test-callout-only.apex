Boolean healthy = ERPIntegrationService.healthCheck();
System.debug('HEALTH_CHECK=' + healthy);

Sales_Order__c order = [
    SELECT Id, Status__c, Account__c, Order_Date__c, Total_Amount__c, Description__c, ERP_Order_Id__c
    FROM Sales_Order__c
    WHERE Id = 'a01bm00002hbNjqAAE'
    LIMIT 1
];

ERPIntegrationService.SyncResult result = ERPIntegrationService.syncOrderToERP(
    order,
    ERPIntegrationService.OPERATION_CREATE
);

System.debug('CALL_SUCCESS=' + result.success);
System.debug('CALL_HTTP=' + result.httpStatusCode);
System.debug('CALL_ERP_ID=' + result.erpOrderId);
System.debug('CALL_ERROR=' + result.errorMessage);
