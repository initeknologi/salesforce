/**
 * @description Provides ERP integration configuration from Custom Metadata.
 *              Centralizes config access for testability and maintainability.
 */
public with sharing class ERPSettingsProvider {
    private static ERP_Integration_Setting__mdt cachedSettings;

    public static ERP_Integration_Setting__mdt getSettings() {
        if (cachedSettings == null) {
            List<ERP_Integration_Setting__mdt> settings = [
                SELECT API_Base_URL__c, API_Key__c, Timeout_Ms__c,
                       Is_Active__c, Max_Retry_Attempts__c, Named_Credential__c
                FROM ERP_Integration_Setting__mdt
                WHERE Is_Active__c = true
                LIMIT 1
            ];
            cachedSettings = settings.isEmpty() ? null : settings[0];
        }
        return cachedSettings;
    }

    @TestVisible
    static void clearCache() {
        cachedSettings = null;
    }

    public static Boolean isIntegrationActive() {
        ERP_Integration_Setting__mdt settings = getSettings();
        return settings != null && settings.Is_Active__c;
    }

    /**
     * @description Validates inbound REST API requests using Bearer token from Custom Metadata.
     */
    public static Boolean isValidInboundApiKey(String authorizationHeader) {
        ERP_Integration_Setting__mdt settings = getSettings();
        if (settings == null || String.isBlank(settings.API_Key__c)) {
            return false;
        }
        if (String.isBlank(authorizationHeader)) {
            return false;
        }
        return authorizationHeader == 'Bearer ' + settings.API_Key__c;
    }
}
