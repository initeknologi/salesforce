// Idempotent, minimal dataset for the Sales Cloud + Service Cloud interview scenario.
Account customer = new Account(
    Name = 'Nordic Telecom AB',
    BC_Customer_Id__c = 'BC-CUST-1001',
    Customer_Segment__c = 'Telecom',
    Region__c = 'Nordics',
    BillingCountry = 'Sweden'
);
upsert customer BC_Customer_Id__c;

List<Contact> contacts = [
    SELECT Id
    FROM Contact
    WHERE AccountId = :customer.Id AND Email = 'anna.lindberg@example.com'
    LIMIT 1
];
if (contacts.isEmpty()) {
    insert new Contact(
        FirstName = 'Anna',
        LastName = 'Lindberg',
        Email = 'anna.lindberg@example.com',
        Title = 'Network Operations Manager',
        AccountId = customer.Id
    );
}

List<Product2> products = [
    SELECT Id
    FROM Product2
    WHERE ProductCode = 'BAT-48V'
    LIMIT 1
];
Product2 batteryProduct;
if (products.isEmpty()) {
    batteryProduct = new Product2(
        Name = 'Battery Cabinet 48V',
        ProductCode = 'BAT-48V',
        Family = 'Hardware',
        IsActive = true,
        Description = 'Modular lithium-ion backup power cabinet.'
    );
    insert batteryProduct;
} else {
    batteryProduct = products[0];
}

List<Opportunity> opportunities = [
    SELECT Id, StageName
    FROM Opportunity
    WHERE AccountId = :customer.Id
      AND Name = 'Sweden 5G Backup Expansion'
    LIMIT 1
];
Opportunity expansion;
if (opportunities.isEmpty()) {
    expansion = new Opportunity(
        Name = 'Sweden 5G Backup Expansion',
        AccountId = customer.Id,
        StageName = 'Closed Won',
        CloseDate = Date.today(),
        Amount = 250000,
        Description = 'Battery backup rollout for 5G telecom sites in Sweden.'
    );
    insert expansion;
} else {
    expansion = opportunities[0];
    if (expansion.StageName != 'Closed Won') {
        expansion.StageName = 'Closed Won';
        expansion.CloseDate = Date.today();
        update expansion;
    }
}

OpportunityOrderService.Request orderRequest =
    new OpportunityOrderService.Request();
orderRequest.opportunityId = expansion.Id;
OpportunityOrderService.createDraftOrders(
    new List<OpportunityOrderService.Request>{ orderRequest }
);

List<Asset> assets = [
    SELECT Id
    FROM Asset
    WHERE SerialNumber = 'SE-STH-001'
    LIMIT 1
];
Asset installedBattery;
if (assets.isEmpty()) {
    installedBattery = new Asset(
        Name = 'Battery Cabinet SE-STH-001',
        AccountId = customer.Id,
        Product2Id = batteryProduct.Id,
        SerialNumber = 'SE-STH-001',
        Status = 'Installed',
        InstallDate = Date.today().addMonths(-6),
        PurchaseDate = Date.today().addMonths(-7)
    );
    insert installedBattery;
} else {
    installedBattery = assets[0];
}

List<Case> cases = [
    SELECT Id
    FROM Case
    WHERE AccountId = :customer.Id
      AND Subject = 'Battery module temperature warning'
    LIMIT 1
];
Case warrantyCase;
if (cases.isEmpty()) {
    warrantyCase = new Case(
        AccountId = customer.Id,
        AssetId = installedBattery.Id,
        Subject = 'Battery module temperature warning',
        Description = 'Site telemetry reports repeated high-temperature alarms.',
        Status = 'New',
        Origin = 'Web',
        Support_Process__c = 'Warranty'
    );
    insert warrantyCase;
} else {
    warrantyCase = cases[0];
}

WarrantyCaseService.Request caseRequest = new WarrantyCaseService.Request();
caseRequest.caseId = warrantyCase.Id;
WarrantyCaseService.triageCases(
    new List<WarrantyCaseService.Request>{ caseRequest }
);

System.debug('Customer: ' + customer.Id);
System.debug('Opportunity: ' + expansion.Id);
System.debug('Asset: ' + installedBattery.Id);
System.debug('Warranty Case: ' + warrantyCase.Id);
