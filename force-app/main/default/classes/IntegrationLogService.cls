/**
 * @description Service layer for Integration Log records.
 *              Provides centralized audit logging for all ERP integration activities.
 */
public with sharing class IntegrationLogService {
    public enum LogStatus { SUCCESS, FAILED, PENDING }

    public static Integration_Log__c createLog(
        Id salesOrderId,
        String direction,
        String operation,
        LogStatus status,
        String requestPayload,
        String responsePayload,
        Integer httpStatusCode,
        String errorMessage,
        Long durationMs
    ) {
        Integration_Log__c log = new Integration_Log__c(
            Sales_Order__c = salesOrderId,
            Direction__c = direction,
            Operation__c = operation,
            Status__c = status.name().substring(0, 1) +
                         status.name().substring(1).toLowerCase(),
            Request_Payload__c = truncate(requestPayload, 131072),
            Response_Payload__c = truncate(responsePayload, 131072),
            HTTP_Status_Code__c = httpStatusCode,
            Error_Message__c = truncate(errorMessage, 32768),
            Duration_Ms__c = durationMs
        );
        return log;
    }

    public static void insertLogs(List<Integration_Log__c> logs) {
        if (logs.isEmpty()) {
            return;
        }
        Database.SaveResult[] results = Database.insert(logs, false);
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                System.debug(LoggingLevel.WARN,
                    'Integration log insert failed: ' + sr.getErrors()[0].getMessage());
            }
        }
    }

    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}
