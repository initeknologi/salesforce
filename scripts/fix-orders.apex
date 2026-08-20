TriggerHandler.bypass('SalesOrderTriggerHandler');
Account acct = [SELECT Id FROM Account LIMIT 1];
Sales_Order__c synced = [SELECT Id, Name FROM Sales_Order__c WHERE Name = 'SO-00000' LIMIT 1];
synced.Status__c = 'Synced';
synced.ERP_Order_Id__c = 'BC-ORD-003';
synced.Sync_Error_Message__c = null;
synced.Last_Sync_Date__c = Datetime.now();
update synced;
Integer failedCount = [SELECT COUNT() FROM Sales_Order__c WHERE Status__c = 'Sync Failed'];
if (failedCount == 0) {
    insert new Sales_Order__c(
        Account__c = acct.Id,
        Order_Date__c = Date.today().addDays(-1),
        Total_Amount__c = 2500.00,
        Status__c = 'Sync Failed',
        Description__c = 'Bulk order - ERP connection timeout during sync',
        Sync_Error_Message__c = 'HTTP 408: ERP endpoint unreachable. Verify tunnel and mock server on port 3001.',
        Last_Sync_Date__c = Datetime.now().addHours(-2)
    );
}
TriggerHandler.clearBypass('SalesOrderTriggerHandler');