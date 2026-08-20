/**
 * @description Handles REST API communication with Microsoft Dynamics 365 Business Central.
 *              Implements outbound integration with comprehensive error handling and logging.
 */
public with sharing class ERPIntegrationService {
    public static final String OPERATION_CREATE = 'Create Order';
    public static final String OPERATION_UPDATE = 'Update Order';
    public static final String OPERATION_CANCEL = 'Cancel Order';

    public class SyncResult {
        public Boolean success;
        public String erpOrderId;
        public String errorMessage;
        public Integer httpStatusCode;
        public String responseBody;
    }

    public class ERPOrderPayload {
        public String externalId;
        public String customerNumber;
        public String orderDate;
        public Decimal totalAmount;
        public String description;
        public String status;
    }

    /**
     * @description Synchronizes a sales order to the ERP system via REST API.
     */
    public static SyncResult syncOrderToERP(Sales_Order__c order, String operation) {
        SyncResult result = new SyncResult();
        result.success = false;

        ERP_Integration_Setting__mdt settings = ERPSettingsProvider.getSettings();
        if (settings == null || !settings.Is_Active__c) {
            result.errorMessage = 'ERP integration is not configured or inactive.';
            return result;
        }

        Long startTime = System.currentTimeMillis();
        String requestBody = buildRequestPayload(order);
        String endpoint = buildEndpoint(settings, order, operation);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(getHttpMethod(operation));
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + settings.API_Key__c);
        req.setHeader('Accept', 'application/json');
        req.setHeader('Bypass-Tunnel-Reminder', 'true');
        req.setBody(requestBody);
        req.setTimeout(Integer.valueOf(settings.Timeout_Ms__c ?? 30000));

        try {
            HttpResponse res = new Http().send(req);
            result.httpStatusCode = res.getStatusCode();
            result.responseBody = res.getBody();

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                result.success = true;
                result.erpOrderId = parseErpOrderId(res.getBody());
            } else {
                result.errorMessage = 'ERP API returned status ' + res.getStatusCode() +
                    ': ' + res.getStatus();
            }
        } catch (Exception ex) {
            result.errorMessage = ex.getMessage();
            result.httpStatusCode = 0;
        }

        Long duration = System.currentTimeMillis() - startTime;
        logIntegration(order.Id, operation, requestBody, result, duration);

        return result;
    }

    /**
     * @description Performs a health check against the ERP API.
     */
    public static Boolean healthCheck() {
        ERP_Integration_Setting__mdt settings = ERPSettingsProvider.getSettings();
        if (settings == null) {
            return false;
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.API_Base_URL__c + '/health');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + settings.API_Key__c);
        req.setHeader('Bypass-Tunnel-Reminder', 'true');
        req.setTimeout(10000);

        try {
            HttpResponse res = new Http().send(req);
            return res.getStatusCode() == 200;
        } catch (Exception ex) {
            return false;
        }
    }

    @TestVisible
    private static String buildRequestPayload(Sales_Order__c order) {
        ERPOrderPayload payload = new ERPOrderPayload();
        payload.externalId = order.Id;
        payload.customerNumber = order.Account__c != null ? String.valueOf(order.Account__c) : '';
        payload.orderDate = order.Order_Date__c != null
            ? String.valueOf(order.Order_Date__c) : '';
        payload.totalAmount = order.Total_Amount__c;
        payload.description = order.Description__c;
        payload.status = order.Status__c;
        return JSON.serialize(payload);
    }

    @TestVisible
    private static String buildEndpoint(
        ERP_Integration_Setting__mdt settings,
        Sales_Order__c order,
        String operation
    ) {
        String baseUrl = settings.API_Base_URL__c;
        if (operation == OPERATION_CREATE) {
            return baseUrl + '/salesOrders';
        } else if (operation == OPERATION_UPDATE) {
            return baseUrl + '/salesOrders(' + order.ERP_Order_Id__c + ')';
        } else if (operation == OPERATION_CANCEL) {
            return baseUrl + '/salesOrders(' + order.ERP_Order_Id__c + ')/cancel';
        }
        return baseUrl + '/salesOrders';
    }

    @TestVisible
    private static String getHttpMethod(String operation) {
        if (operation == OPERATION_CREATE) {
            return 'POST';
        } else if (operation == OPERATION_UPDATE) {
            return 'PATCH';
        } else if (operation == OPERATION_CANCEL) {
            return 'POST';
        }
        return 'POST';
    }

    @TestVisible
    private static String parseErpOrderId(String responseBody) {
        if (String.isBlank(responseBody)) {
            return null;
        }
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        return parsed.containsKey('id') ? String.valueOf(parsed.get('id')) : null;
    }

    private static void logIntegration(
        Id orderId,
        String operation,
        String requestBody,
        SyncResult result,
        Long durationMs
    ) {
        IntegrationLogService.LogStatus status = result.success
            ? IntegrationLogService.LogStatus.SUCCESS
            : IntegrationLogService.LogStatus.FAILED;

        Integration_Log__c log = IntegrationLogService.createLog(
            orderId,
            'Outbound',
            operation,
            status,
            requestBody,
            result.responseBody,
            result.httpStatusCode,
            result.errorMessage,
            durationMs
        );
        IntegrationLogService.insertLogs(new List<Integration_Log__c>{ log });
    }
}
