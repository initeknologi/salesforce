@IsTest
private class ERPSettingsProviderTest {
    @IsTest
    static void isValidInboundApiKey_acceptsMatchingBearerToken() {
        System.assert(
            ERPSettingsProvider.isValidInboundApiKey('Bearer demo-api-key-local-dev'),
            'Valid bearer token should be accepted'
        );
    }

    @IsTest
    static void isValidInboundApiKey_rejectsInvalidToken() {
        System.assert(
            !ERPSettingsProvider.isValidInboundApiKey('Bearer wrong-key'),
            'Invalid bearer token should be rejected'
        );
    }

    @IsTest
    static void isValidInboundApiKey_rejectsBlankHeader() {
        System.assert(
            !ERPSettingsProvider.isValidInboundApiKey(null),
            'Blank authorization should be rejected'
        );
    }
}
