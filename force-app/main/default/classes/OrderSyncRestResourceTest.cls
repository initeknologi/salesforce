@IsTest
private class OrderSyncRestResourceTest {
  @IsTest
  static void handleStatusCallback_success() {
    Account acc = new Account(Name = 'Callback Test');
    insert acc;

    Sales_Order__c order = new Sales_Order__c(
      Account__c = acc.Id,
      Order_Date__c = Date.today(),
      Total_Amount__c = 1000,
      Status__c = 'Syncing'
    );
    insert order;

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/services/apexrest/erp/v1/orders/' + order.Id;
    req.httpMethod = 'POST';
    req.addHeader('Authorization', 'Bearer demo-api-key-local-dev');
    req.requestBody = Blob.valueOf(
      '{"status":"Released","erpOrderId":"BC-ORD-999"}'
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    OrderSyncRestResource.ResponseWrapper response =
      OrderSyncRestResource.handleStatusCallback();
    Test.stopTest();

    System.assert(response.success);
    System.assertEquals(200, res.statusCode);

    Sales_Order__c updated = [
      SELECT Status__c, ERP_Order_Id__c
      FROM Sales_Order__c
      WHERE Id = :order.Id
    ];
    System.assertEquals('Synced', updated.Status__c);
    System.assertEquals('BC-ORD-999', updated.ERP_Order_Id__c);
  }

  @IsTest
  static void handleStatusCallback_unauthorized() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/services/apexrest/erp/v1/orders/001xx';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{"status":"Released"}');
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    OrderSyncRestResource.ResponseWrapper response =
      OrderSyncRestResource.handleStatusCallback();
    Test.stopTest();

    System.assert(!response.success);
    System.assertEquals(401, res.statusCode);
  }

  @IsTest
  static void healthCheck_endpoint() {
    Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.healthCheckSuccess());

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/services/apexrest/erp/v1/orders/health';
    req.httpMethod = 'GET';
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    OrderSyncRestResource.ResponseWrapper response = OrderSyncRestResource.healthCheck();
    Test.stopTest();

    System.assert(response.success);
  }
}
