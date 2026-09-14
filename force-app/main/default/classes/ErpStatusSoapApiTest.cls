@IsTest
private class ErpStatusSoapApiTest {
    @IsTest
    static void ping_returnsOkWhenHealthy() {
        Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.healthCheckSuccess());

        Test.startTest();
        String status = ErpStatusSoapApi.ping('monitoring-client');
        Test.stopTest();

        System.assertEquals('OK', status);
    }

    @IsTest
    static void ping_requiresClientId() {
        System.assertEquals('INVALID_CLIENT', ErpStatusSoapApi.ping(''));
    }
}
