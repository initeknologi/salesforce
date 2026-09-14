@IsTest
private class RecycleBinPurgeBatchTest {
    @IsTest
    static void batch_runsWithoutError() {
        Test.startTest();
        Database.executeBatch(new RecycleBinPurgeBatch('Case'), 200);
        Test.stopTest();
    }
}
