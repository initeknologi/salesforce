@IsTest
private class OrderReconciliationBatchTest {
    @TestSetup
    static void setup() {
        Account acc = new Account(
            Name = 'Reconciliation Account',
            BC_Customer_Id__c = 'BC-CUST-9001'
        );
        insert acc;

        insert new Sales_Order__c(
            Account__c = acc.Id,
            Order_Date__c = Date.today(),
            Total_Amount__c = 1000,
            Status__c = 'Synced',
            ERP_Order_Id__c = 'BC-ORD-001',
            Correlation_Id__c = 'corr-001'
        );
    }

    @IsTest
    static void reconciliation_logsMismatchWhenErpMissing() {
        Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.emptySalesOrderList());

        Test.startTest();
        Database.executeBatch(new OrderReconciliationBatch(), 10);
        Test.stopTest();

        Integer mismatchCount = [
            SELECT COUNT()
            FROM Integration_Log__c
            WHERE Operation__c = 'Reconciliation Mismatch'
        ];
        Integer summaryCount = [
            SELECT COUNT()
            FROM Integration_Log__c
            WHERE Operation__c = 'Reconciliation Summary'
        ];
        System.assertEquals(1, mismatchCount, 'Expected one mismatch log');
        System.assertEquals(1, summaryCount, 'Expected one summary log');
    }

    @IsTest
    static void reconciliation_passesWhenErpMatches() {
        Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.salesOrderListMatch());

        Test.startTest();
        Database.executeBatch(new OrderReconciliationBatch(), 10);
        Test.stopTest();

        List<Integration_Log__c> mismatches = [
            SELECT Id
            FROM Integration_Log__c
            WHERE Operation__c = 'Reconciliation Mismatch'
        ];
        System.assertEquals(0, mismatches.size());
    }
}
