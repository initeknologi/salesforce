@IsTest
private class SalesOrderServiceTest {
  @TestSetup
  static void setup() {
    insert new Account(Name = 'Acme Corp');
  }

  @IsTest
  static void validateOrders_negativeAmount() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Sales_Order__c order = new Sales_Order__c(
      Account__c = acc.Id,
      Order_Date__c = Date.today(),
      Total_Amount__c = -100,
      Status__c = 'Draft'
    );

    Test.startTest();
    Database.SaveResult sr = Database.insert(order, false);
    Test.stopTest();

    System.assert(!sr.isSuccess(), 'Should reject negative amount');
  }

  @IsTest
  static void syncOrderToERP_manualSync() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Sales_Order__c order = new Sales_Order__c(
      Account__c = acc.Id,
      Order_Date__c = Date.today(),
      Total_Amount__c = 2000,
      Status__c = 'Submitted'
    );
    insert order;

    Test.setMock(HttpCalloutMock.class, ERPIntegrationMock.successCreate());

    Test.startTest();
    String message = SalesOrderService.syncOrderToERP(order.Id);
    Test.stopTest();

    System.assert(message.contains('successfully'), 'Should return success message');

    Sales_Order__c updated = [
      SELECT Status__c, ERP_Order_Id__c
      FROM Sales_Order__c
      WHERE Id = :order.Id
    ];
    System.assertEquals('Synced', updated.Status__c);
    System.assertEquals('BC-ORD-001', updated.ERP_Order_Id__c);
  }

  @IsTest
  static void getOrderSummary_returnsCounts() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    insert new List<Sales_Order__c>{
      new Sales_Order__c(
        Account__c = acc.Id,
        Order_Date__c = Date.today(),
        Total_Amount__c = 100,
        Status__c = 'Draft'
      ),
      new Sales_Order__c(
        Account__c = acc.Id,
        Order_Date__c = Date.today(),
        Total_Amount__c = 200,
        Status__c = 'Synced'
      )
    };

    Test.startTest();
    Map<String, Integer> summary = SalesOrderService.getOrderSummary();
    Test.stopTest();

    System.assertEquals(2, summary.get('total'));
    System.assertEquals(1, summary.get('draft'));
    System.assertEquals(1, summary.get('synced'));
  }

  @IsTest
  static void publishSyncEvents_createsPlatformEvent() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Sales_Order__c order = new Sales_Order__c(
      Account__c = acc.Id,
      Order_Date__c = Date.today(),
      Total_Amount__c = 300,
      Status__c = 'Submitted'
    );
    insert order;

    Test.startTest();
    SalesOrderService.publishSyncEvents(new List<Sales_Order__c>{ order }, null);
    Test.stopTest();
  }

  @IsTest
  static void updateSuccessWithoutResponseId_preservesExistingErpId() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Sales_Order__c order = new Sales_Order__c(
      Account__c = acc.Id,
      Order_Date__c = Date.today(),
      Total_Amount__c = 300,
      Status__c = 'Syncing',
      ERP_Order_Id__c = 'BC-ORD-EXISTING'
    );
    insert order;

    ERPIntegrationService.SyncResult result = new ERPIntegrationService.SyncResult();
    result.success = true;
    result.erpOrderId = null;

    SalesOrderService.updateOrdersAfterSync(
      new List<Sales_Order__c>{ order },
      new Map<Id, ERPIntegrationService.SyncResult>{ order.Id => result }
    );

    order = [
      SELECT Status__c, ERP_Order_Id__c
      FROM Sales_Order__c
      WHERE Id = :order.Id
    ];
    System.assertEquals('Synced', order.Status__c);
    System.assertEquals('BC-ORD-EXISTING', order.ERP_Order_Id__c);
  }

  @IsTest
  static void getOrdersRequiringSync_handlesSubmitCancelAndFailure() {
    Id orderId = Sales_Order__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Sales_Order__c oldOrder = new Sales_Order__c(
      Id = orderId,
      Status__c = 'Syncing',
      ERP_Order_Id__c = 'BC-ORD-001'
    );

    Sales_Order__c cancelledOrder = oldOrder.clone(true, true, false, false);
    cancelledOrder.Status__c = 'Cancelled';
    System.assertEquals(
      1,
      SalesOrderService.getOrdersRequiringSync(
        new List<Sales_Order__c>{ cancelledOrder },
        new Map<Id, Sales_Order__c>{ orderId => oldOrder }
      ).size()
    );

    Sales_Order__c failedOrder = oldOrder.clone(true, true, false, false);
    failedOrder.Status__c = 'Sync Failed';
    System.assertEquals(
      0,
      SalesOrderService.getOrdersRequiringSync(
        new List<Sales_Order__c>{ failedOrder },
        new Map<Id, Sales_Order__c>{ orderId => oldOrder }
      ).size(),
      'Internal failure status must not reset the retry counter'
    );
  }
}
