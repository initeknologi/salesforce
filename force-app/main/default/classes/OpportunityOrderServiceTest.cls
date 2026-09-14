@IsTest
private class OpportunityOrderServiceTest {
    @TestSetup
    static void setup() {
        insert new Account(Name = 'Nordic Telecom AB');
    }

    @IsTest
    static void createsOneDraftOrderForClosedWonOpportunity() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opportunity = new Opportunity(
            Name = 'Sweden 5G Backup Expansion',
            AccountId = account.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 250000
        );
        insert opportunity;

        OpportunityOrderService.Request request =
            new OpportunityOrderService.Request();
        request.opportunityId = opportunity.Id;

        Test.startTest();
        List<OpportunityOrderService.Result> results =
            OpportunityOrderService.createDraftOrders(
                new List<OpportunityOrderService.Request>{ request }
            );
        Test.stopTest();

        System.assertEquals('Draft order created', results[0].outcome);
        Sales_Order__c order = [
            SELECT Account__c, Opportunity__c, Status__c, Total_Amount__c,
                   Currency_Code__c, Correlation_Id__c
            FROM Sales_Order__c
            WHERE Opportunity__c = :opportunity.Id
        ];
        System.assertEquals(account.Id, order.Account__c);
        System.assertEquals('Draft', order.Status__c);
        System.assertEquals(250000, order.Total_Amount__c);
        System.assertEquals('SEK', order.Currency_Code__c);
        System.assertEquals('OPP-' + opportunity.Id, order.Correlation_Id__c);

        opportunity = [
            SELECT ERP_Sync_Status__c, Generated_Sales_Order__c
            FROM Opportunity
            WHERE Id = :opportunity.Id
        ];
        System.assertEquals('Ready', opportunity.ERP_Sync_Status__c);
        System.assertEquals(order.Id, opportunity.Generated_Sales_Order__c);
    }

    @IsTest
    static void duplicateInvocationReturnsExistingOrder() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opportunity = new Opportunity(
            Name = 'Duplicate Guard',
            AccountId = account.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 1000
        );
        insert opportunity;

        OpportunityOrderService.Request request =
            new OpportunityOrderService.Request();
        request.opportunityId = opportunity.Id;

        Test.startTest();
        OpportunityOrderService.createDraftOrders(
            new List<OpportunityOrderService.Request>{ request }
        );
        List<OpportunityOrderService.Result> secondResults =
            OpportunityOrderService.createDraftOrders(
                new List<OpportunityOrderService.Request>{ request }
            );
        Test.stopTest();

        System.assertEquals('Order already exists', secondResults[0].outcome);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Sales_Order__c WHERE Opportunity__c = :opportunity.Id]
        );
    }

    @IsTest
    static void rejectsIneligibleOpportunity() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opportunity = new Opportunity(
            Name = 'Open Opportunity',
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 5000
        );
        insert opportunity;

        OpportunityOrderService.Request request =
            new OpportunityOrderService.Request();
        request.opportunityId = opportunity.Id;

        List<OpportunityOrderService.Result> results =
            OpportunityOrderService.createDraftOrders(
                new List<OpportunityOrderService.Request>{ request }
            );

        System.assertEquals('Opportunity is not Closed Won', results[0].outcome);
        System.assertEquals(0, [SELECT COUNT() FROM Sales_Order__c]);
    }
}
