@IsTest
private class WarrantyReturnServiceTest {
    @TestSetup
    static void setup() {
        Account acc = new Account(
            Name = 'Warranty Account',
            BC_Customer_Id__c = 'BC-CUST-2001'
        );
        insert acc;

        insert new Case(
            AccountId = acc.Id,
            Subject = 'Battery replacement',
            Status = 'Working',
            Support_Process__c = 'Warranty',
            RMA_Status__c = 'Approved',
            Integration_Status__c = 'Not Started'
        );
    }

    @IsTest
    static void syncReturnOrder_createsErpReturn() {
        Case supportCase = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Battery replacement'
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.successReturnCreate());

        WarrantyReturnService.Request request = new WarrantyReturnService.Request();
        request.caseId = supportCase.Id;

        Test.startTest();
        List<WarrantyReturnService.Result> results = WarrantyReturnService.syncReturnOrders(
            new List<WarrantyReturnService.Request>{ request }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Return order created', results[0].outcome);

        Case updated = [
            SELECT BC_Return_Order_Id__c, RMA_Status__c, Integration_Status__c
            FROM Case
            WHERE Id = :supportCase.Id
        ];
        System.assertEquals('BC-RET-001', updated.BC_Return_Order_Id__c);
        System.assertEquals('Sent to ERP', updated.RMA_Status__c);
        System.assertEquals('Synced', updated.Integration_Status__c);
    }

    @IsTest
    static void syncReturnOrder_isIdempotent() {
        Case supportCase = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Battery replacement'
            LIMIT 1
        ];
        supportCase.BC_Return_Order_Id__c = 'BC-RET-EXISTING';
        update supportCase;

        WarrantyReturnService.Request request = new WarrantyReturnService.Request();
        request.caseId = supportCase.Id;

        Test.startTest();
        List<WarrantyReturnService.Result> results = WarrantyReturnService.syncReturnOrders(
            new List<WarrantyReturnService.Request>{ request }
        );
        Test.stopTest();

        System.assertEquals('Return order already synced', results[0].outcome);
        System.assertEquals('BC-RET-EXISTING', results[0].returnOrderId);
    }
}
