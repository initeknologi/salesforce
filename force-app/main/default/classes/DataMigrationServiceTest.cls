@IsTest
private class DataMigrationServiceTest {
  @TestSetup
  static void setup() {
    insert new Account(Name = 'Migration Corp');
  }

  @IsTest
  static void importOrders_validData() {
    String payload =
      '[{"accountName":"Migration Corp","orderDate":"2025-01-15",' +
      '"totalAmount":5000,"description":"Bulk import","status":"Draft"}]';

    Test.startTest();
    DataMigrationService.MigrationResult result =
      DataMigrationService.importOrders(payload);
    Test.stopTest();

    System.assertEquals(1, result.totalRecords);
    System.assertEquals(1, result.successCount);
    System.assertEquals(0, result.errorCount);
  }

  @IsTest
  static void importOrders_invalidData() {
    String payload = '[{"accountName":"","orderDate":null,"totalAmount":-1}]';

    Test.startTest();
    DataMigrationService.MigrationResult result =
      DataMigrationService.importOrders(payload);
    Test.stopTest();

    System.assert(result.errorCount > 0, 'Should have validation errors');
  }
}
