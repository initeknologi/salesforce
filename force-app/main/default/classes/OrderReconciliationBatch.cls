public with sharing class OrderReconciliationBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private Integer mismatchCount = 0;
    private Map<String, Map<String, Object>> erpOrdersByExternalId;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Correlation_Id__c, ERP_Order_Id__c, Total_Amount__c, Status__c
            FROM Sales_Order__c
            WHERE Status__c = 'Synced'
              AND ERP_Order_Id__c != NULL
            ORDER BY LastModifiedDate DESC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Sales_Order__c> scope) {
        if (erpOrdersByExternalId == null) {
            erpOrdersByExternalId = ERPIntegrationService.fetchSalesOrdersByExternalId();
        }

        List<Integration_Log__c> logs = new List<Integration_Log__c>();
        for (Sales_Order__c order : scope) {
            String externalId = String.isNotBlank(order.Correlation_Id__c)
                ? order.Correlation_Id__c
                : String.valueOf(order.Id);
            Map<String, Object> erpOrder = erpOrdersByExternalId.get(externalId);

            if (erpOrder == null) {
                mismatchCount++;
                logs.add(buildMismatchLog(
                    order.Id,
                    externalId,
                    'ERP order not found for external id ' + externalId
                ));
                continue;
            }

            String erpId = erpOrder.containsKey('id')
                ? String.valueOf(erpOrder.get('id'))
                : null;
            if (erpId != order.ERP_Order_Id__c) {
                mismatchCount++;
                logs.add(buildMismatchLog(
                    order.Id,
                    externalId,
                    'ERP id mismatch. SF=' + order.ERP_Order_Id__c + ', ERP=' + erpId
                ));
            }
        }

        if (!logs.isEmpty()) {
            IntegrationLogService.insertLogs(logs);
        }
    }

    public void finish(Database.BatchableContext bc) {
        IntegrationLogService.insertLogs(new List<Integration_Log__c>{
            IntegrationLogService.createLog(
                null,
                'Outbound',
                'Reconciliation Summary',
                IntegrationLogService.LogStatus.SUCCESS,
                'Reconciliation completed with ' + mismatchCount + ' mismatch(es).',
                null,
                200,
                null,
                0
            )
        });
    }

    private static Integration_Log__c buildMismatchLog(
        Id orderId,
        String externalId,
        String message
    ) {
        return IntegrationLogService.createLog(
            orderId,
            'Outbound',
            'Reconciliation Mismatch',
            IntegrationLogService.LogStatus.FAILED,
            externalId,
            null,
            409,
            message,
            0
        );
    }
}
