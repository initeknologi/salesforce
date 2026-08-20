@IsTest
private class OrderSyncEventHandlerTest {
    @TestSetup
    static void setup() {
        insert new Account(Name = 'Event Handler Account');
    }

    @IsTest
    static void handleEvents_enqueuesQueueable() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c order = new Sales_Order__c(
            Account__c = acc.Id,
            Order_Date__c = Date.today(),
            Total_Amount__c = 500,
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
        OrderSyncEventHandler.handleEvents(new List<Order_Sync_Event__e>{ evt });
        Test.stopTest();

        Sales_Order__c updated = [
            SELECT Status__c
            FROM Sales_Order__c
            WHERE Id = :order.Id
        ];
        System.assertEquals('Synced', updated.Status__c);
    }
}
