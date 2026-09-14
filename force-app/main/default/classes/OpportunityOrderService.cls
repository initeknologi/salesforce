public with sharing class OpportunityOrderService {
    public class Request {
        @InvocableVariable(required=true)
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable
        public Id opportunityId;
        @InvocableVariable
        public Id salesOrderId;
        @InvocableVariable
        public String outcome;
    }

    @InvocableMethod(
        label='Create Draft ERP Sales Order'
        description='Draft Sales Order from Closed Won Opportunity'
    )
    public static List<Result> createDraftOrders(List<Request> requests) {
        Set<Id> opportunityIds = new Set<Id>();
        for (Request request : requests) {
            if (request != null && request.opportunityId != null) {
                opportunityIds.add(request.opportunityId);
            }
        }

        Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>([
            SELECT Id, Name, AccountId, Amount, StageName, IsWon
            FROM Opportunity
            WHERE Id IN :opportunityIds
            WITH USER_MODE
        ]);

        Map<Id, Sales_Order__c> existingByOpportunity = new Map<Id, Sales_Order__c>();
        for (Sales_Order__c existing : [
            SELECT Id, Opportunity__c
            FROM Sales_Order__c
            WHERE Opportunity__c IN :opportunityIds
            WITH USER_MODE
        ]) {
            existingByOpportunity.put(existing.Opportunity__c, existing);
        }

        List<Sales_Order__c> ordersToInsert = new List<Sales_Order__c>();
        Map<Id, Sales_Order__c> pendingByOpportunity = new Map<Id, Sales_Order__c>();
        List<Result> results = new List<Result>();

        for (Request request : requests) {
            Result result = new Result();
            result.opportunityId = request == null ? null : request.opportunityId;

            Opportunity opportunity = opportunities.get(result.opportunityId);
            if (opportunity == null) {
                result.outcome = 'Opportunity not found';
            } else if (!opportunity.IsWon || opportunity.StageName != 'Closed Won') {
                result.outcome = 'Opportunity is not Closed Won';
            } else if (opportunity.AccountId == null || opportunity.Amount == null ||
                opportunity.Amount <= 0) {
                result.outcome = 'Account and positive Amount are required';
            } else if (existingByOpportunity.containsKey(opportunity.Id)) {
                result.salesOrderId = existingByOpportunity.get(opportunity.Id).Id;
                result.outcome = 'Order already exists';
            } else if (pendingByOpportunity.containsKey(opportunity.Id)) {
                result.outcome = 'Skipped duplicate';
            } else {
                Sales_Order__c order = new Sales_Order__c(
                    Account__c = opportunity.AccountId,
                    Opportunity__c = opportunity.Id,
                    Order_Date__c = Date.today(),
                    Total_Amount__c = opportunity.Amount,
                    Currency_Code__c = 'SEK',
                    Correlation_Id__c = 'OPP-' + opportunity.Id,
                    Status__c = 'Draft',
                    Description__c = 'Generated from Opportunity ' + opportunity.Name
                );
                ordersToInsert.add(order);
                pendingByOpportunity.put(opportunity.Id, order);
                result.outcome = 'Draft order created';
            }
            results.add(result);
        }

        if (!ordersToInsert.isEmpty()) {
            SObjectAccessDecision insertDecision = Security.stripInaccessible(
                AccessType.CREATABLE,
                ordersToInsert
            );
            List<Sales_Order__c> safeOrders =
                (List<Sales_Order__c>) insertDecision.getRecords();
            insert safeOrders;

            Map<Id, Id> orderIdByOpportunity = new Map<Id, Id>();
            for (Sales_Order__c order : safeOrders) {
                orderIdByOpportunity.put(order.Opportunity__c, order.Id);
            }

            List<Opportunity> opportunityUpdates = new List<Opportunity>();
            for (Id opportunityId : orderIdByOpportunity.keySet()) {
                opportunityUpdates.add(new Opportunity(
                    Id = opportunityId,
                    ERP_Sync_Status__c = 'Ready',
                    Generated_Sales_Order__c = orderIdByOpportunity.get(opportunityId)
                ));
            }
            SObjectAccessDecision updateDecision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                opportunityUpdates
            );
            update updateDecision.getRecords();

            for (Result result : results) {
                if (orderIdByOpportunity.containsKey(result.opportunityId)) {
                    result.salesOrderId = orderIdByOpportunity.get(result.opportunityId);
                }
            }
        }

        return results;
    }
}
