@IsTest
private class BceidContactMapperTest {
    @IsTest
    static void testAllSpreadsheetMappingsAndIdempotence() {
        Contact target = new Contact(
            FirstName = 'Original', LastName = 'Original',
            Email = 'old@example.com', MobilePhone = '6045550000'
        );
        BceidPersonData data = new BceidPersonData('New', 'Person',
            'new@example.com', '+1 (438) 788-6958');
        System.assertEquals(true, BceidContactMapper.apply(target, data));
        System.assertEquals('New', target.FirstName);
        System.assertEquals('Person', target.LastName);
        System.assertEquals('new@example.com', target.Email);
        System.assertEquals('4387886958', target.MobilePhone);
        System.assertEquals(false, BceidContactMapper.apply(target, data));
    }

    @IsTest
    static void testBlankAndInvalidValuesCannotClearFields() {
        Contact target = new Contact(
            FirstName = 'Safe', LastName = 'Person',
            Email = 'safe@example.com', MobilePhone = '6045559999'
        );
        BceidPersonData data = new BceidPersonData(' ', null,
            '', '123');
        System.assertEquals(false, BceidContactMapper.apply(target, data));
        System.assertEquals('Safe', target.FirstName);
        System.assertEquals('Person', target.LastName);
        System.assertEquals('safe@example.com', target.Email);
        System.assertEquals('6045559999', target.MobilePhone);
    }
}
