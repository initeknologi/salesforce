// Ensures both Synced and Sync Failed orders exist for screenshots.
Account acct = [SELECT Id FROM Account LIMIT 1];

List<Sales_Order__c> orders = [
    SELECT Id, Name, Status__c, ERP_Order_Id__c
    FROM Sales_Order__c
    ORDER BY Name
];

Sales_Order__c synced = null;
Sales_Order__c failed = null;
for (Sales_Order__c o : orders) {
    if (o.Status__c == 'Synced') synced = o;
    if (o.Status__c == 'Sync Failed') failed = o;
}

if (synced == null && !orders.isEmpty()) {
    synced = orders[0];
    synced.Status__c = 'Synced';
    synced.ERP_Order_Id__c = 'BC-ORD-003';
    synced.Sync_Error_Message__c = null;
    synced.Last_Sync_Date__c = Datetime.now();
    update synced;
}

if (failed == null) {
    failed = new Sales_Order__c(
        Account__c = acct.Id,
        Order_Date__c = Date.today().addDays(-1),
        Total_Amount__c = 2500.00,
        Status__c = 'Sync Failed',
        Description__c = 'Bulk order — ERP connection timeout during sync',
        Sync_Error_Message__c = 'HTTP 408: ERP endpoint unreachable. Verify tunnel and mock server on port 3001.',
        Last_Sync_Date__c = Datetime.now().addHours(-2)
    );
    insert failed;
    System.debug('Created Sync Failed order: ' + failed.Id);
} else {
    failed.Sync_Error_Message__c =
        'HTTP 408: ERP endpoint unreachable. Verify tunnel and mock server on port 3001.';
    update failed;
    System.debug('Updated Sync Failed order: ' + failed.Name);
}
