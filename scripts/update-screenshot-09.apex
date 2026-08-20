TriggerHandler.bypass('SalesOrderTriggerHandler');
Sales_Order__c order = [
    SELECT Id, Name, Status__c, Sync_Error_Message__c, ERP_Order_Id__c
    FROM Sales_Order__c
    WHERE Name = 'SO-00000'
    LIMIT 1
];
order.Status__c = 'Sync Failed';
order.Sync_Error_Message__c =
    'HTTP 408: ERP endpoint unreachable. Verify tunnel and mock server on port 3001.';
order.Description__c = 'Bulk order - ERP connection timeout during sync';
order.Last_Sync_Date__c = Datetime.now();
update order;
TriggerHandler.clearBypass('SalesOrderTriggerHandler');
