public with sharing class WarrantyReturnService {
    public class Request {
        @InvocableVariable(required=true)
        public Id caseId;
    }

    public class Result {
        @InvocableVariable
        public Id caseId;
        @InvocableVariable
        public String returnOrderId;
        @InvocableVariable
        public String outcome;
    }

    @InvocableMethod(
        label='Sync Approved RMA to ERP'
        description='ERP return order for approved RMA'
    )
    public static List<Result> syncReturnOrders(List<Request> requests) {
        Set<Id> caseIds = new Set<Id>();
        for (Request request : requests) {
            if (request != null && request.caseId != null) {
                caseIds.add(request.caseId);
            }
        }

        Map<Id, Case> casesById = new Map<Id, Case>([
            SELECT Id, CaseNumber, AccountId, Account.BC_Customer_Id__c,
                   Support_Process__c, RMA_Status__c, Integration_Status__c,
                   BC_Return_Order_Id__c
            FROM Case
            WHERE Id IN :caseIds
            WITH USER_MODE
        ]);

        List<Case> casesToUpdate = new List<Case>();
        List<Result> results = new List<Result>();

        for (Request request : requests) {
            Result result = new Result();
            result.caseId = request == null ? null : request.caseId;
            Case supportCase = casesById.get(result.caseId);

            if (supportCase == null) {
                result.outcome = 'Case not found';
            } else if (supportCase.Support_Process__c != 'Warranty') {
                result.outcome = 'Case is not a warranty case';
            } else if (supportCase.RMA_Status__c != 'Approved') {
                result.outcome = 'RMA is not approved';
            } else if (String.isNotBlank(supportCase.BC_Return_Order_Id__c)) {
                result.returnOrderId = supportCase.BC_Return_Order_Id__c;
                result.outcome = 'Return order already synced';
            } else {
                ERPIntegrationService.ReturnSyncResult syncResult =
                    ERPIntegrationService.syncReturnOrderToERP(supportCase);

                IntegrationLogService.insertLogs(new List<Integration_Log__c>{
                    IntegrationLogService.createLog(
                        null,
                        'Outbound',
                        'Create Return Order',
                        syncResult.success
                            ? IntegrationLogService.LogStatus.SUCCESS
                            : IntegrationLogService.LogStatus.FAILED,
                        ERPIntegrationService.buildReturnOrderPayload(supportCase),
                        syncResult.responseBody,
                        syncResult.httpStatusCode,
                        syncResult.errorMessage,
                        0
                    )
                });

                if (syncResult.success) {
                    casesToUpdate.add(new Case(
                        Id = supportCase.Id,
                        BC_Return_Order_Id__c = syncResult.returnOrderId,
                        RMA_Status__c = 'Sent to ERP',
                        Integration_Status__c = 'Synced'
                    ));
                    result.returnOrderId = syncResult.returnOrderId;
                    result.outcome = 'Return order created';
                } else {
                    casesToUpdate.add(new Case(
                        Id = supportCase.Id,
                        Integration_Status__c = 'Failed'
                    ));
                    result.outcome = syncResult.errorMessage;
                }
            }
            results.add(result);
        }

        if (!casesToUpdate.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                casesToUpdate
            );
            update decision.getRecords();
        }

        return results;
    }
}
