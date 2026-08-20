@IsTest
private class OrderSyncBatchTest {
    @TestSetup
    static void setup() {
        insert new Account(Name = 'Batch Test Account');
    }

    @IsTest
    static void batch_syncsSubmittedOrders() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        insert new Sales_Order__c(
            Account__c = acc.Id,
            Order_Date__c = Date.today(),
            Total_Amount__c = 1500,
            Status__c = 'Submitted'
        );

        Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.successCreate());

        Test.startTest();
        Database.executeBatch(new OrderSyncBatch(), 1);
        Test.stopTest();

        Sales_Order__c updated = [
            SELECT Status__c, ERP_Order_Id__c
            FROM Sales_Order__c
            LIMIT 1
        ];
        System.assertEquals('Synced', updated.Status__c);
        System.assertEquals('BC-ORD-001', updated.ERP_Order_Id__c);
    }
}
