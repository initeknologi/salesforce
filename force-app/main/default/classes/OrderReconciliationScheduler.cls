public with sharing class OrderReconciliationScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        Database.executeBatch(new OrderReconciliationBatch(), 50);
    }
}
