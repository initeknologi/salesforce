@IsTest
private class OrderSyncQueueableTest {
    @TestSetup
    static void setup() {
        insert new Account(Name = 'Queueable Test Account');
    }

    @IsTest
    static void execute_syncsOrderWithoutDmlBeforeCallout() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c order = new Sales_Order__c(
            Account__c = acc.Id,
            Order_Date__c = Date.today(),
            Total_Amount__c = 1200,
            Status__c = 'Submitted'
        );
        insert order;

        Order_Sync_Event__e evt = new Order_Sync_Event__e(
            Sales_Order_Id__c = order.Id,
            Operation__c = 'CREATE',
            Retry_Count__c = 0
        );

        Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.successCreate());

        Test.startTest();
        System.enqueueJob(new OrderSyncQueueable(new List<Order_Sync_Event__e>{ evt }));
        Test.stopTest();

        Sales_Order__c updated = [
            SELECT Status__c, ERP_Order_Id__c
            FROM Sales_Order__c
            WHERE Id = :order.Id
        ];
        System.assertEquals('Synced', updated.Status__c);
        System.assertEquals('BC-ORD-001', updated.ERP_Order_Id__c);
    }

    @IsTest
    static void shouldSkipSync_skipsAlreadySyncedOrder() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c order = new Sales_Order__c(
            Account__c = acc.Id,
            Order_Date__c = Date.today(),
            Total_Amount__c = 900,
            Status__c = 'Synced',
            ERP_Order_Id__c = 'BC-ORD-EXISTING'
        );
        insert order;

        Boolean skip = OrderSyncQueueable.shouldSkipSync(
            order,
            ERPIntegrationService.OPERATION_CREATE
        );
        System.assert(skip, 'Already synced orders should be skipped on create');
    }

    @IsTest
    static void execute_retriesOnFailure() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c order = new Sales_Order__c(
            Account__c = acc.Id,
            Order_Date__c = Date.today(),
            Total_Amount__c = 800,
            Status__c = 'Submitted'
        );
        insert order;

        Order_Sync_Event__e evt = new Order_Sync_Event__e(
            Sales_Order_Id__c = order.Id,
            Operation__c = 'CREATE',
            Retry_Count__c = 0
        );

        Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.serverError());

        Test.startTest();
        System.enqueueJob(new OrderSyncQueueable(new List<Order_Sync_Event__e>{ evt }));
        Test.stopTest();

        Sales_Order__c updated = [
            SELECT Status__c, Sync_Error_Message__c
            FROM Sales_Order__c
            WHERE Id = :order.Id
        ];
        System.assertEquals('Sync Failed', updated.Status__c);
        System.assertNotEquals(null, updated.Sync_Error_Message__c);
    }
}
