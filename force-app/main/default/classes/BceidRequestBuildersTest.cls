@IsTest
private class BceidRequestBuildersTest {
    @IsTest
    static void testGetAccountDetailMatchesWsdlSequenceAndNamespace() {
        String detail = BceidRequestBuilders.getAccountDetail(
            'os1',
            'Business',
            '',
            'REQUESTER-GUID',
            '',
            'TARGET-GUID',
            'Business'
        );

        String expected =
            '<v10:onlineServiceId>os1</v10:onlineServiceId>' +
            '<v10:requesterAccountTypeCode>Business' +
            '</v10:requesterAccountTypeCode>' +
            '<v10:requesterUserId></v10:requesterUserId>' +
            '<v10:requesterUserGuid>REQUESTER-GUID' +
            '</v10:requesterUserGuid>' +
            '<v10:userId></v10:userId>' +
            '<v10:userGuid>TARGET-GUID</v10:userGuid>' +
            '<v10:accountTypeCode>Business</v10:accountTypeCode>';

        System.assertEquals(expected, detail);
    }

    @IsTest
    static void testGetAccountDetailCompatibilityOverload() {
        String detail = BceidRequestBuilders.getAccountDetail(
            'os1',
            'Business',
            'REQUESTER-GUID',
            'TARGET-GUID',
            '',
            'Business'
        );

        System.assert(
            detail.contains(
                '<v10:requesterUserId></v10:requesterUserId>'
            )
        );
        System.assert(
            detail.contains(
                '<v10:requesterUserGuid>REQUESTER-GUID' +
                '</v10:requesterUserGuid>'
            )
        );
        System.assert(
            detail.indexOf('<v10:userId>') <
            detail.indexOf('<v10:userGuid>')
        );
    }

    @IsTest
    static void testGetAccountDetailListUsesQualifiedElements() {
        BceidRequestBuilders.AccountDetailItem item =
            new BceidRequestBuilders.AccountDetailItem();
        item.userGuid = 'UG3';
        item.userId = 'user3';
        item.accountTypeCode = 'Business';
        item.clientKey = 'k1';

        String listXml =
            BceidRequestBuilders.getAccountDetailList(
                'os1',
                'Business',
                'UG1',
                new List<BceidRequestBuilders.AccountDetailItem>{
                    item
                }
            );

        System.assert(listXml.contains('<v10:requestItemList>'));
        System.assert(
            listXml.contains('<v10:AccountDetailListRequestItem>')
        );
        System.assert(
            listXml.contains('<v10:userId>user3</v10:userId>')
        );
        System.assert(
            listXml.contains('<v10:clientKey>k1</v10:clientKey>')
        );
    }

    @IsTest
    static void testSearchBuildersUseQualifiedElements() {
        String searchBceid =
            BceidRequestBuilders.searchBceidAccount(
                'os1',
                'Business',
                'UG1',
                'Ascending',
                'UserId',
                500,
                1,
                'Business',
                'abc',
                'StartsWith',
                'Smith',
                'Exact',
                true,
                false
            );

        System.assert(searchBceid.contains('<v10:pagination>'));
        System.assert(
            searchBceid.contains(
                '<v10:searchableAccountType>Business' +
                '</v10:searchableAccountType>'
            )
        );
        System.assert(searchBceid.contains('<v10:businessMatch>'));

        String searchInternal =
            BceidRequestBuilders.searchInternalAccount(
                'os1',
                'Internal',
                'UG1',
                'Descending',
                'LastName',
                100,
                1,
                'cservant',
                'StartsWith'
            );

        System.assert(searchInternal.contains('<v10:sort>'));
        System.assert(searchInternal.contains('<v10:accountMatch>'));
        System.assert(
            searchInternal.contains(
                '<v10:value>cservant</v10:value>'
            )
        );
    }

    @IsTest
    static void testSubscriptionAndGroupBuilders() {
        String subs =
            BceidRequestBuilders.getSubscriptionCodeList(
                'os1',
                'UG1'
            );
        System.assert(
            subs.contains('<v10:userGuid>UG1</v10:userGuid>')
        );

        BceidRequestBuilders.GroupMatch g1 =
            new BceidRequestBuilders.GroupMatch();
        g1.groupGuid = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

        BceidRequestBuilders.GroupMatch g2 =
            new BceidRequestBuilders.GroupMatch();
        g2.groupName = 'MY_GROUP';

        String groups =
            BceidRequestBuilders.getInternalUserGroupInfo(
                'os1',
                'Internal',
                'UG1',
                'UG2',
                new List<BceidRequestBuilders.GroupMatch>{ g1, g2 }
            );

        System.assert(groups.contains('<v10:groupMatches>'));
        System.assert(
            groups.contains(
                '<v10:groupGuid>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' +
                '</v10:groupGuid>'
            )
        );
        System.assert(
            groups.contains(
                '<v10:groupName>MY_GROUP</v10:groupName>'
            )
        );
    }

    @IsTest
    static void testCreateSubscriptionBatchEscapesSpecialCharacters() {
        BceidRequestBuilders.SubscriptionItem s =
            new BceidRequestBuilders.SubscriptionItem();
        s.osKey = 'os&1';
        s.codeType = 'Regular';
        s.scope = 'Individual';
        s.question = 'What is 2 < 3?';
        s.answer = 'It\'s 2 & 3';
        s.accountTypeCode = 'Business';
        s.initialActivationPeriod = 90;

        String xml =
            BceidRequestBuilders.createSubscriptionBatch(
                'os1',
                'Business',
                'UG1',
                'Batch & one',
                'Regular',
                new List<BceidRequestBuilders.SubscriptionItem>{ s }
            );

        System.assert(xml.contains('&amp;'));
        System.assert(xml.contains('&lt;'));
        System.assert(xml.contains('&apos;'));
        System.assert(
            xml.contains(
                '<v10:anyType xsi:type="v10:BCeIDSubscription">'
            )
        );
        System.assert(
            xml.contains(
                '<v10:initialActivationPeriod>90' +
                '</v10:initialActivationPeriod>'
            )
        );
    }
}