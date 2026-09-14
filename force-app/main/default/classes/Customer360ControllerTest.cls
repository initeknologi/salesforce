@IsTest
private class Customer360ControllerTest {
    @IsTest
    static void returnsCrossCloudSummary() {
        Account account = new Account(
            Name = 'Nordic Telecom AB',
            BC_Customer_Id__c = 'BC-CUST-1001',
            Customer_Segment__c = 'Telecom',
            Region__c = 'Nordics'
        );
        insert account;
        insert new Opportunity(
            Name = 'Sweden Expansion',
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        Product2 product = new Product2(Name = 'Battery', IsActive = true);
        insert product;
        insert new Asset(
            Name = 'Installed Battery',
            AccountId = account.Id,
            Product2Id = product.Id,
            Status = 'Installed'
        );
        insert new Case(
            AccountId = account.Id,
            Subject = 'Temperature warning',
            Status = 'New',
            Origin = 'Web'
        );
        insert new Sales_Order__c(
            Account__c = account.Id,
            Order_Date__c = Date.today(),
            Total_Amount__c = 1000,
            Status__c = 'Sync Failed'
        );

        Test.startTest();
        Customer360Controller.Summary summary =
            Customer360Controller.getSummary(account.Id);
        Test.stopTest();

        System.assertEquals('Nordic Telecom AB', summary.accountName);
        System.assertEquals('Telecom', summary.customerSegment);
        System.assertEquals(1, summary.openOpportunities);
        System.assertEquals(1, summary.salesOrders);
        System.assertEquals(1, summary.installedAssets);
        System.assertEquals(1, summary.openCases);
        System.assertEquals(1, summary.failedIntegrations);
    }

    @IsTest
    static void rejectsMissingAccountId() {
        try {
            Customer360Controller.getSummary(null);
            System.assert(false, 'Expected an AuraHandledException');
        } catch (AuraHandledException expected) {
            System.assertNotEquals(null, expected);
        }
    }
}
