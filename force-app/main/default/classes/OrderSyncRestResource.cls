/**
 * @description Inbound REST API for ERP status callbacks from Dynamics 365 Business Central.
 *              URL: /services/apexrest/erp/v1/orders/*
 */
@RestResource(urlMapping='/erp/v1/orders/*')
global with sharing class OrderSyncRestResource {
    @HttpPost
    global static ResponseWrapper handleStatusCallback() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        ResponseWrapper response = new ResponseWrapper();

        if (!ERPSettingsProvider.isValidInboundApiKey(req.headers.get('Authorization'))) {
            res.statusCode = 401;
            response.success = false;
            response.message = 'Unauthorized.';
            return response;
        }

        try {
            String orderId = extractOrderId(req.requestURI);
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
                req.requestBody.toString()
            );

            String erpStatus = (String) payload.get('status');
            String erpOrderId = (String) payload.get('erpOrderId');

            List<Sales_Order__c> orders = [
                SELECT Id, Status__c, ERP_Order_Id__c
                FROM Sales_Order__c
                WHERE Id = :orderId OR ERP_Order_Id__c = :erpOrderId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (orders.isEmpty()) {
                res.statusCode = 404;
                response.success = false;
                response.message = 'Order not found.';
                return response;
            }

            Sales_Order__c order = orders[0];
            order.Status__c = mapErpStatus(erpStatus);
            order.ERP_Order_Id__c = erpOrderId;
            order.Last_Sync_Date__c = System.now();
            update order;

            Integration_Log__c log = IntegrationLogService.createLog(
                order.Id,
                'Inbound',
                'Status Callback',
                IntegrationLogService.LogStatus.SUCCESS,
                req.requestBody.toString(),
                JSON.serialize(response),
                200,
                null,
                0
            );
            IntegrationLogService.insertLogs(new List<Integration_Log__c>{ log });

            res.statusCode = 200;
            response.success = true;
            response.message = 'Order status updated successfully.';
            response.salesforceOrderId = order.Id;

        } catch (Exception ex) {
            res.statusCode = 500;
            response.success = false;
            response.message = ex.getMessage();
        }

        return response;
    }

    @HttpGet
    global static ResponseWrapper healthCheck() {
        RestResponse res = RestContext.response;
        ResponseWrapper response = new ResponseWrapper();
        response.success = ERPIntegrationService.healthCheck();
        response.message = response.success ? 'ERP connection healthy.' : 'ERP connection failed.';
        res.statusCode = response.success ? 200 : 503;
        return response;
    }

    private static String extractOrderId(String uri) {
        String[] parts = uri.split('/');
        return parts[parts.size() - 1];
    }

    private static String mapErpStatus(String erpStatus) {
        Map<String, String> statusMap = new Map<String, String>{
            'Open' => 'Synced',
            'Released' => 'Synced',
            'Cancelled' => 'Cancelled',
            'Failed' => 'Sync Failed'
        };
        return statusMap.containsKey(erpStatus) ? statusMap.get(erpStatus) : 'Synced';
    }

    global class ResponseWrapper {
        public Boolean success;
        public String message;
        public String salesforceOrderId;
    }
}
