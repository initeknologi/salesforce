Sales_Order__c order = [
    SELECT Id, Name, Status__c, Account__c, Order_Date__c,
           Total_Amount__c, Description__c, ERP_Order_Id__c
    FROM Sales_Order__c
    WHERE Id = 'a01bm00002hbNjqAAE'
    LIMIT 1
];

ERPIntegrationService.SyncResult result = ERPIntegrationService.syncOrderToERP(
    order,
    ERPIntegrationService.OPERATION_CREATE
);

if (result.success) {
    order.Status__c = 'Synced';
    order.ERP_Order_Id__c = result.erpOrderId;
    order.Sync_Error_Message__c = null;
    order.Last_Sync_Date__c = System.now();
} else {
    order.Status__c = 'Sync Failed';
    order.Sync_Error_Message__c = result.errorMessage;
    order.Last_Sync_Date__c = System.now();
}
update order;

System.debug('CALL_SUCCESS=' + result.success);
System.debug('CALL_HTTP=' + result.httpStatusCode);
System.debug('CALL_ERP_ID=' + result.erpOrderId);
System.debug('CALL_ERROR=' + result.errorMessage);
System.debug('FINAL_STATUS=' + order.Status__c);
