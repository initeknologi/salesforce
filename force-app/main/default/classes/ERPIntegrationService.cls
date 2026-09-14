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
        public String currencyCode;
        public String description;
        public String status;
    }

    public class ReturnSyncResult {
        public Boolean success;
        public String returnOrderId;
        public String errorMessage;
        public Integer httpStatusCode;
        public String responseBody;
    }

    public class ReturnOrderPayload {
        public String externalId;
        public String customerNumber;
        public String caseNumber;
        public String reason;
    }

    public static SyncResult syncOrderToERP(Sales_Order__c order, String operation) {
        return syncOrderToERP(order, operation, true);
    }

    public static SyncResult syncOrderToERP(
        Sales_Order__c order,
        String operation,
        Boolean persistLog
    ) {
        SyncResult result = new SyncResult();
        result.success = false;

        ERP_Integration_Setting__mdt settings = ERPSettingsProvider.getSettings();
        if (settings == null || !settings.Is_Active__c) {
            result.errorMessage = 'ERP integration is not configured or inactive.';
            return result;
        }

        Long startTime = System.currentTimeMillis();
        String requestBody = buildRequestPayload(order);
        String path = buildPath(order, operation);

        HttpRequest req = new HttpRequest();
        configureRequest(req, settings, path);
        req.setMethod(getHttpMethod(operation));
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader(
            'Idempotency-Key',
            String.isNotBlank(order.Correlation_Id__c)
                ? order.Correlation_Id__c
                : String.valueOf(order.Id)
        );
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
        if (persistLog) {
            IntegrationLogService.insertLogs(new List<Integration_Log__c>{
                buildIntegrationLog(order.Id, operation, requestBody, result, duration)
            });
        }

        return result;
    }

    public static Map<String, Map<String, Object>> fetchSalesOrdersByExternalId() {
        Map<String, Map<String, Object>> indexed =
            new Map<String, Map<String, Object>>();
        ERP_Integration_Setting__mdt settings = ERPSettingsProvider.getSettings();
        if (settings == null || !settings.Is_Active__c) {
            return indexed;
        }

        HttpRequest req = new HttpRequest();
        configureRequest(req, settings, '/salesOrders');
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Bypass-Tunnel-Reminder', 'true');
        req.setTimeout(Integer.valueOf(settings.Timeout_Ms__c ?? 30000));

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                return indexed;
            }
            Map<String, Object> parsed =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> rows = parsed.containsKey('value')
                ? (List<Object>) parsed.get('value')
                : new List<Object>();
            for (Object row : rows) {
                Map<String, Object> order = (Map<String, Object>) row;
                String externalId = order.containsKey('externalId')
                    ? String.valueOf(order.get('externalId'))
                    : null;
                if (String.isNotBlank(externalId)) {
                    indexed.put(externalId, order);
                }
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'ERP list fetch failed: ' + ex.getMessage());
        }
        return indexed;
    }

    public static ReturnSyncResult syncReturnOrderToERP(Case supportCase) {
        ReturnSyncResult result = new ReturnSyncResult();
        result.success = false;

        ERP_Integration_Setting__mdt settings = ERPSettingsProvider.getSettings();
        if (settings == null || !settings.Is_Active__c) {
            result.errorMessage = 'ERP integration is not configured or inactive.';
            return result;
        }

        String requestBody = buildReturnOrderPayload(supportCase);
        HttpRequest req = new HttpRequest();
        configureRequest(req, settings, '/returnOrders');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Idempotency-Key', 'RMA-' + supportCase.Id);
        req.setHeader('Bypass-Tunnel-Reminder', 'true');
        req.setBody(requestBody);
        req.setTimeout(Integer.valueOf(settings.Timeout_Ms__c ?? 30000));

        try {
            HttpResponse res = new Http().send(req);
            result.httpStatusCode = res.getStatusCode();
            result.responseBody = res.getBody();
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                result.success = true;
                result.returnOrderId = parseReturnOrderId(res.getBody());
            } else {
                result.errorMessage = 'ERP API returned status ' + res.getStatusCode();
            }
        } catch (Exception ex) {
            result.errorMessage = ex.getMessage();
            result.httpStatusCode = 0;
        }
        return result;
    }

    public static Boolean healthCheck() {
        ERP_Integration_Setting__mdt settings = ERPSettingsProvider.getSettings();
        if (settings == null) {
            return false;
        }

        HttpRequest req = new HttpRequest();
        configureRequest(req, settings, '/health');
        req.setMethod('GET');
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
    private static void configureRequest(
        HttpRequest req,
        ERP_Integration_Setting__mdt settings,
        String path
    ) {
        if (String.isNotBlank(settings.Named_Credential__c)) {
            req.setEndpoint('callout:' + settings.Named_Credential__c + path);
            if (String.isNotBlank(settings.API_Key__c)) {
                req.setHeader('Authorization', 'Bearer ' + settings.API_Key__c);
            }
        } else {
            req.setEndpoint(settings.API_Base_URL__c + path);
            req.setHeader('Authorization', 'Bearer ' + settings.API_Key__c);
        }
    }

    public static String buildRequestPayload(Sales_Order__c order) {
        ERPOrderPayload payload = new ERPOrderPayload();
        payload.externalId = String.isNotBlank(order.Correlation_Id__c)
            ? order.Correlation_Id__c
            : String.valueOf(order.Id);
        payload.customerNumber = order.Account__r != null &&
            String.isNotBlank(order.Account__r.BC_Customer_Id__c)
            ? order.Account__r.BC_Customer_Id__c
            : String.valueOf(order.Account__c);
        payload.orderDate = order.Order_Date__c != null
            ? String.valueOf(order.Order_Date__c) : '';
        payload.totalAmount = order.Total_Amount__c;
        payload.currencyCode = order.Currency_Code__c;
        payload.description = order.Description__c;
        payload.status = order.Status__c;
        return JSON.serialize(payload);
    }

    @TestVisible
    private static String buildPath(Sales_Order__c order, String operation) {
        if (operation == OPERATION_CREATE) {
            return '/salesOrders';
        } else if (operation == OPERATION_UPDATE) {
            return '/salesOrders(' + order.ERP_Order_Id__c + ')';
        } else if (operation == OPERATION_CANCEL) {
            return '/salesOrders(' + order.ERP_Order_Id__c + ')/cancel';
        }
        return '/salesOrders';
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

    @TestVisible
    private static String parseReturnOrderId(String responseBody) {
        return parseErpOrderId(responseBody);
    }

    public static String buildReturnOrderPayload(Case supportCase) {
        ReturnOrderPayload payload = new ReturnOrderPayload();
        payload.externalId = 'CASE-' + supportCase.Id;
        payload.customerNumber = supportCase.Account != null &&
            String.isNotBlank(supportCase.Account.BC_Customer_Id__c)
            ? supportCase.Account.BC_Customer_Id__c
            : String.valueOf(supportCase.AccountId);
        payload.caseNumber = supportCase.CaseNumber;
        payload.reason = 'Warranty RMA';
        return JSON.serialize(payload);
    }

    public static Integration_Log__c buildIntegrationLog(
        Id orderId,
        String operation,
        String requestBody,
        SyncResult result,
        Long durationMs
    ) {
        IntegrationLogService.LogStatus status = result.success
            ? IntegrationLogService.LogStatus.SUCCESS
            : IntegrationLogService.LogStatus.FAILED;

        return IntegrationLogService.createLog(
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
    }
}
