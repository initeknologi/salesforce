@IsTest
private class WarrantyCaseServiceTest {
    @TestSetup
    static void setup() {
        Account account = new Account(Name = 'Nordic Telecom AB');
        insert account;
        Product2 product = new Product2(
            Name = 'Battery Cabinet',
            ProductCode = 'BAT-48V',
            IsActive = true
        );
        insert product;
        insert new Asset(
            Name = 'Battery Cabinet SE-STH-001',
            AccountId = account.Id,
            Product2Id = product.Id,
            SerialNumber = 'SE-STH-001',
            Status = 'Installed',
            InstallDate = Date.today().addMonths(-6)
        );
    }

    @IsTest
    static void triagesWarrantyCaseAndCreatesOneTask() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Asset asset = [SELECT Id FROM Asset LIMIT 1];
        Case supportCase = new Case(
            AccountId = account.Id,
            AssetId = asset.Id,
            Subject = 'Battery module temperature warning',
            Status = 'New',
            Origin = 'Web',
            Support_Process__c = 'Warranty'
        );
        insert supportCase;

        WarrantyCaseService.Request request = new WarrantyCaseService.Request();
        request.caseId = supportCase.Id;

        Test.startTest();
        List<WarrantyCaseService.Result> firstResults =
            WarrantyCaseService.triageCases(
                new List<WarrantyCaseService.Request>{ request }
            );
        List<WarrantyCaseService.Result> secondResults =
            WarrantyCaseService.triageCases(
                new List<WarrantyCaseService.Request>{ request }
            );
        Test.stopTest();

        supportCase = [
            SELECT Priority, RMA_Status__c, Integration_Status__c
            FROM Case
            WHERE Id = :supportCase.Id
        ];
        System.assertEquals('High', supportCase.Priority);
        System.assertEquals('Requested', supportCase.RMA_Status__c);
        System.assertEquals('Not Started', supportCase.Integration_Status__c);
        // The active record-triggered Flow triages the Case during insert.
        System.assertEquals('Task already open', firstResults[0].outcome);
        System.assertEquals('Task already open', secondResults[0].outcome);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Task WHERE WhatId = :supportCase.Id]
        );
    }

    @IsTest
    static void ignoresNonWarrantyCase() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Case supportCase = new Case(
            AccountId = account.Id,
            Subject = 'Billing question',
            Status = 'New',
            Origin = 'Phone',
            Support_Process__c = 'Billing'
        );
        insert supportCase;

        WarrantyCaseService.Request request = new WarrantyCaseService.Request();
        request.caseId = supportCase.Id;
        List<WarrantyCaseService.Result> results =
            WarrantyCaseService.triageCases(
                new List<WarrantyCaseService.Request>{ request }
            );

        System.assertEquals('Case is not a warranty case', results[0].outcome);
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :supportCase.Id]);
    }
}
