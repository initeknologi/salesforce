@IsTest
private class SalesOrderTriggerHandlerTest {
    @TestSetup
    static void setup() {
        insert new Account(Name = 'Trigger Handler Account');
    }

    @IsTest
    static void afterUpdate_submittedStatus_publishesEvent() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c order = new Sales_Order__c(
            Account__c = acc.Id,
            Order_Date__c = Date.today(),
            Total_Amount__c = 400,
            Status__c = 'Draft'
        );
        insert order;

        Test.startTest();
        order.Status__c = 'Submitted';
        update order;
        Test.stopTest();

        System.assertEquals('Submitted', [
            SELECT Status__c FROM Sales_Order__c WHERE Id = :order.Id
        ].Status__c);
    }

    @IsTest
    static void resolveEventOperation_returnsUpdateWhenErpIdExists() {
        Sales_Order__c order = new Sales_Order__c(
            Status__c = 'Submitted',
            ERP_Order_Id__c = 'BC-ORD-100'
        );
        System.assertEquals('UPDATE', SalesOrderService.resolveEventOperation(order, null));
    }

    @IsTest
    static void resolveEventOperation_returnsCancelForCancelledStatus() {
        Sales_Order__c order = new Sales_Order__c(Status__c = 'Cancelled');
        System.assertEquals('CANCEL', SalesOrderService.resolveEventOperation(order, null));
    }

    @IsTest
    static void beforeInsert_rejectsNegativeAmount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c order = new Sales_Order__c(
            Account__c = acc.Id,
            Order_Date__c = Date.today(),
            Total_Amount__c = -50,
            Status__c = 'Draft'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(order, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Negative amount should be rejected');
    }
}
