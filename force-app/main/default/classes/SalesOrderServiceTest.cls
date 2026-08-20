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
    SalesOrderService.publishSyncEvents(new List<Sales_Order__c>{ order }, 'CREATE');
    Test.stopTest();
  }
}
