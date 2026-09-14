public with sharing class Customer360Controller {
    public class Summary {
        @AuraEnabled public String accountName;
        @AuraEnabled public String customerSegment;
        @AuraEnabled public String region;
        @AuraEnabled public String bcCustomerId;
        @AuraEnabled public Integer openOpportunities;
        @AuraEnabled public Integer salesOrders;
        @AuraEnabled public Integer installedAssets;
        @AuraEnabled public Integer openCases;
        @AuraEnabled public Integer failedIntegrations;
    }

    @AuraEnabled(cacheable=true)
    public static Summary getSummary(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account ID is required.');
        }

        Account account = [
            SELECT Name, Customer_Segment__c, Region__c, BC_Customer_Id__c
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];

        Summary summary = new Summary();
        summary.accountName = account.Name;
        summary.customerSegment = account.Customer_Segment__c;
        summary.region = account.Region__c;
        summary.bcCustomerId = account.BC_Customer_Id__c;
        summary.openOpportunities = [
            SELECT COUNT()
            FROM Opportunity
            WHERE AccountId = :accountId AND IsClosed = false
            WITH USER_MODE
        ];
        summary.salesOrders = [
            SELECT COUNT()
            FROM Sales_Order__c
            WHERE Account__c = :accountId
            WITH USER_MODE
        ];
        summary.installedAssets = [
            SELECT COUNT()
            FROM Asset
            WHERE AccountId = :accountId AND Status = 'Installed'
            WITH USER_MODE
        ];
        summary.openCases = [
            SELECT COUNT()
            FROM Case
            WHERE AccountId = :accountId AND IsClosed = false
            WITH USER_MODE
        ];
        summary.failedIntegrations = [
            SELECT COUNT()
            FROM Sales_Order__c
            WHERE Account__c = :accountId AND Status__c = 'Sync Failed'
            WITH USER_MODE
        ];
        return summary;
    }
}
