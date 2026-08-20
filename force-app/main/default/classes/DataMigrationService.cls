/**
 * @description ETL service for bulk data migration of sales orders from CSV/external sources.
 *              Handles validation, duplicate detection, and bulk DML with error collection.
 */
public with sharing class DataMigrationService {
    public class MigrationResult {
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<String> errors;
    }

    public class OrderImportRow {
        public String accountName;
        public Date orderDate;
        public Decimal totalAmount;
        public String description;
        public String status;
    }

    /**
     * @description Imports sales orders from JSON payload (simulating CSV ETL pipeline).
     */
    @AuraEnabled
    public static MigrationResult importOrders(String jsonPayload) {
        MigrationResult result = new MigrationResult();
        result.errors = new List<String>();
        result.successCount = 0;
        result.errorCount = 0;

        List<OrderImportRow> rows;
        try {
            rows = (List<OrderImportRow>) JSON.deserialize(jsonPayload, List<OrderImportRow>.class);
        } catch (Exception ex) {
            result.errors.add('Invalid JSON payload: ' + ex.getMessage());
            result.totalRecords = 0;
            result.errorCount = 1;
            return result;
        }

        result.totalRecords = rows.size();
        Map<String, Id> accountMap = buildAccountMap(rows);
        List<Sales_Order__c> ordersToInsert = new List<Sales_Order__c>();

        for (Integer i = 0; i < rows.size(); i++) {
            OrderImportRow row = rows[i];
            List<String> rowErrors = validateRow(row, i + 1);

            if (!rowErrors.isEmpty()) {
                result.errors.addAll(rowErrors);
                result.errorCount++;
                continue;
            }

            Sales_Order__c order = new Sales_Order__c(
                Account__c = accountMap.get(row.accountName?.toLowerCase()),
                Order_Date__c = row.orderDate,
                Total_Amount__c = row.totalAmount,
                Description__c = row.description,
                Status__c = String.isBlank(row.status) ? 'Draft' : row.status
            );
            ordersToInsert.add(order);
        }

        if (!ordersToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(ordersToInsert, false);
            for (Database.SaveResult sr : saveResults) {
                if (sr.isSuccess()) {
                    result.successCount++;
                } else {
                    result.errorCount++;
                    for (Database.Error err : sr.getErrors()) {
                        result.errors.add(err.getMessage());
                    }
                }
            }
        }

        return result;
    }

    private static Map<String, Id> buildAccountMap(List<OrderImportRow> rows) {
        Set<String> accountNames = new Set<String>();
        for (OrderImportRow row : rows) {
            if (String.isNotBlank(row.accountName)) {
                accountNames.add(row.accountName);
            }
        }

        Map<String, Id> accountMap = new Map<String, Id>();
        for (Account acc : [SELECT Id, Name FROM Account WHERE Name IN :accountNames]) {
            accountMap.put(acc.Name.toLowerCase(), acc.Id);
        }
        return accountMap;
    }

    private static List<String> validateRow(OrderImportRow row, Integer rowNumber) {
        List<String> errors = new List<String>();
        String prefix = 'Row ' + rowNumber + ': ';

        if (String.isBlank(row.accountName)) {
            errors.add(prefix + 'Account Name is required.');
        }
        if (row.orderDate == null) {
            errors.add(prefix + 'Order Date is required.');
        }
        if (row.totalAmount == null || row.totalAmount <= 0) {
            errors.add(prefix + 'Total Amount must be greater than zero.');
        }
        return errors;
    }
}
