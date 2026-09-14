public class RecycleBinPurgeBatch implements Database.Batchable<SObject> {
    private String objectName;

    public RecycleBinPurgeBatch(String objectName) {
        this.objectName = objectName;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id FROM ' + objectName + ' WHERE IsDeleted = true ALL ROWS'
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Database.emptyRecycleBin(scope);
    }

    public void finish(Database.BatchableContext bc) {}
}
