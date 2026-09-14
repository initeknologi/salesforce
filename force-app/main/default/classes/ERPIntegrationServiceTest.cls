@IsTest
private class ERPIntegrationServiceTest {
  @IsTest
  static void syncOrder_create_success() {
    Account acc = new Account(Name = 'Test Customer');
    insert acc;

    Sales_Order__c order = new Sales_Order__c(
      Account__c = acc.Id,
      Order_Date__c = Date.today(),
      Total_Amount__c = 1500.00,
      Status__c = 'Submitted',
      Description__c = 'Test order'
    );
    insert order;

    Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.successCreate());

    Test.startTest();
    ERPIntegrationService.SyncResult result = ERPIntegrationService.syncOrderToERP(
      order,
      ERPIntegrationService.OPERATION_CREATE
    );
    Test.stopTest();

    System.assert(result.success, 'Sync should succeed');
    System.assertEquals('BC-ORD-001', result.erpOrderId);

  List<Integration_Log__c> logs = [SELECT Status__c FROM Integration_Log__c];
    System.assertEquals(1, logs.size());
    System.assertEquals('Success', logs[0].Status__c);
  }

  @IsTest
  static void syncOrder_serverError() {
    Account acc = new Account(Name = 'Error Customer');
    insert acc;

    Sales_Order__c order = new Sales_Order__c(
      Account__c = acc.Id,
      Order_Date__c = Date.today(),
      Total_Amount__c = 500.00,
      Status__c = 'Submitted'
    );
    insert order;

    Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.serverError());

    Test.startTest();
    ERPIntegrationService.SyncResult result = ERPIntegrationService.syncOrderToERP(
      order,
      ERPIntegrationService.OPERATION_CREATE
    );
    Test.stopTest();

    System.assert(!result.success, 'Sync should fail');
    System.assertEquals(500, result.httpStatusCode);
  }

  @IsTest
  static void healthCheck_success() {
    Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.healthCheckSuccess());
    Test.startTest();
    Boolean healthy = ERPIntegrationService.healthCheck();
    Test.stopTest();
    System.assert(healthy, 'Health check should pass');
  }

  @IsTest
  static void fetchSalesOrders_indexesByExternalId() {
    Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.salesOrderListMatch());

    Test.startTest();
    Map<String, Map<String, Object>> indexed =
      ERPIntegrationService.fetchSalesOrdersByExternalId();
    Test.stopTest();

    System.assert(indexed.containsKey('corr-001'));
  }

  @IsTest
  static void syncReturnOrder_success() {
    Account acc = new Account(
      Name = 'Return Customer',
      BC_Customer_Id__c = 'BC-CUST-3001'
    );
    insert acc;

    Case supportCase = new Case(
      AccountId = acc.Id,
      Subject = 'Return test',
      Status = 'Working',
      Support_Process__c = 'Warranty',
      RMA_Status__c = 'Approved'
    );
    insert supportCase;

    supportCase = [
      SELECT Id, CaseNumber, AccountId, Account.BC_Customer_Id__c,
             Support_Process__c, RMA_Status__c
      FROM Case
      WHERE Id = :supportCase.Id
    ];

    Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.successReturnCreate());

    Test.startTest();
    ERPIntegrationService.ReturnSyncResult result =
      ERPIntegrationService.syncReturnOrderToERP(supportCase);
    Test.stopTest();

    System.assert(result.success);
    System.assertEquals('BC-RET-001', result.returnOrderId);
  }
}
