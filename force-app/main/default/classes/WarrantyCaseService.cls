public with sharing class WarrantyCaseService {
    public static final String TASK_SUBJECT =
        'Validate warranty and battery diagnostics';

    public class Request {
        @InvocableVariable(required=true)
        public Id caseId;
    }

    public class Result {
        @InvocableVariable
        public Id caseId;
        @InvocableVariable
        public Id taskId;
        @InvocableVariable
        public String outcome;
    }

    @InvocableMethod(
        label='Triage Warranty Case'
        description='Warranty triage and follow-up Task'
    )
    public static List<Result> triageCases(List<Request> requests) {
        Set<Id> caseIds = new Set<Id>();
        for (Request request : requests) {
            if (request != null && request.caseId != null) {
                caseIds.add(request.caseId);
            }
        }

        Map<Id, Case> casesById = new Map<Id, Case>([
            SELECT Id, OwnerId, AssetId, Support_Process__c, RMA_Status__c
            FROM Case
            WHERE Id IN :caseIds
            WITH USER_MODE
        ]);

        Map<Id, Task> taskByCaseId = new Map<Id, Task>();
        for (Task existingTask : [
            SELECT Id, WhatId
            FROM Task
            WHERE WhatId IN :caseIds
              AND Subject = :TASK_SUBJECT
              AND IsClosed = false
            WITH USER_MODE
        ]) {
            taskByCaseId.put(existingTask.WhatId, existingTask);
        }

        List<Case> casesToUpdate = new List<Case>();
        List<Task> tasksToInsert = new List<Task>();
        Map<Id, Task> pendingTaskByCaseId = new Map<Id, Task>();
        List<Result> results = new List<Result>();

        for (Request request : requests) {
            Result result = new Result();
            result.caseId = request == null ? null : request.caseId;
            Case supportCase = casesById.get(result.caseId);

            if (supportCase == null) {
                result.outcome = 'Case not found';
            } else if (supportCase.Support_Process__c != 'Warranty') {
                result.outcome = 'Case is not a warranty case';
            } else {
                casesToUpdate.add(new Case(
                    Id = supportCase.Id,
                    Priority = supportCase.AssetId == null ? 'Medium' : 'High',
                    RMA_Status__c = 'Requested',
                    Integration_Status__c = 'Not Started'
                ));

                if (taskByCaseId.containsKey(supportCase.Id)) {
                    result.taskId = taskByCaseId.get(supportCase.Id).Id;
                    result.outcome = 'Task already open';
                } else if (pendingTaskByCaseId.containsKey(supportCase.Id)) {
                    result.outcome = 'Skipped duplicate';
                } else {
                    Task followUp = new Task(
                        WhatId = supportCase.Id,
                        OwnerId = supportCase.OwnerId,
                        Subject = TASK_SUBJECT,
                        Status = 'Not Started',
                        Priority = 'High',
                        ActivityDate = Date.today().addDays(1),
                        Description =
                            'Validate entitlement, installed asset, diagnostics, and RMA eligibility.'
                    );
                    tasksToInsert.add(followUp);
                    pendingTaskByCaseId.put(supportCase.Id, followUp);
                    result.outcome = 'Warranty case triaged';
                }
            }
            results.add(result);
        }

        if (!casesToUpdate.isEmpty()) {
            SObjectAccessDecision updateDecision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                casesToUpdate
            );
            update updateDecision.getRecords();
        }

        if (!tasksToInsert.isEmpty()) {
            SObjectAccessDecision createDecision = Security.stripInaccessible(
                AccessType.CREATABLE,
                tasksToInsert
            );
            List<Task> safeTasks = (List<Task>) createDecision.getRecords();
            insert safeTasks;

            Map<Id, Id> taskIdByCaseId = new Map<Id, Id>();
            for (Task task : safeTasks) {
                taskIdByCaseId.put(task.WhatId, task.Id);
            }
            for (Result result : results) {
                if (taskIdByCaseId.containsKey(result.caseId)) {
                    result.taskId = taskIdByCaseId.get(result.caseId);
                }
            }
        }

        return results;
    }
}
