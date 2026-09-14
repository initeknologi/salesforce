global with sharing class ErpStatusSoapApi {
    webservice static String ping(String clientId) {
        if (String.isBlank(clientId)) {
            return 'INVALID_CLIENT';
        }
        return ERPIntegrationService.healthCheck() ? 'OK' : 'UNAVAILABLE';
    }
}
