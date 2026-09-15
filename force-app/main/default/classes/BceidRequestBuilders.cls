public with sharing class BceidRequestBuilders {
    /*
     * WSDL sequence for AccountDetailRequest:
     * RequestBase:
     *   onlineServiceId
     *   requesterAccountTypeCode
     *   requesterUserId
     *   requesterUserGuid
     * AccountDetailRequest:
     *   userId
     *   userGuid
     *   accountTypeCode
     */
    public static String getAccountDetail(
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserId,
        String requesterUserGuid,
        String userId,
        String userGuid,
        String accountTypeCode
    ) {
        return BceidSoapClient.xml('onlineServiceId', onlineServiceId)
            + BceidSoapClient.xml(
                'requesterAccountTypeCode',
                requesterAccountTypeCode
            )
            + BceidSoapClient.xmlEmptyAllowed(
                'requesterUserId',
                requesterUserId
            )
            + BceidSoapClient.xml(
                'requesterUserGuid',
                requesterUserGuid
            )
            + BceidSoapClient.xmlEmptyAllowed('userId', userId)
            + BceidSoapClient.xml('userGuid', userGuid)
            + BceidSoapClient.xml('accountTypeCode', accountTypeCode);
    }

    // Compatibility overload for existing callers.
    public static String getAccountDetail(
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        String userGuid,
        String userId,
        String accountTypeCode
    ) {
        return getAccountDetail(
            onlineServiceId,
            requesterAccountTypeCode,
            '',
            requesterUserGuid,
            userId,
            userGuid,
            accountTypeCode
        );
    }

    public static String getAccountDetailList(
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        List<AccountDetailItem> items
    ) {
        String x = BceidSoapClient.xml('onlineServiceId', onlineServiceId)
            + BceidSoapClient.xml(
                'requesterAccountTypeCode',
                requesterAccountTypeCode
            )
            + BceidSoapClient.xml('requesterUserGuid', requesterUserGuid)
            + BceidSoapClient.openTag('requestItemList');

        if (items != null) {
            for (AccountDetailItem item : items) {
                x += BceidSoapClient.openTag('AccountDetailListRequestItem')
                    + BceidSoapClient.xmlEmptyAllowed('userId', item.userId)
                    + BceidSoapClient.xml('userGuid', item.userGuid)
                    + BceidSoapClient.xml(
                        'accountTypeCode',
                        item.accountTypeCode
                    )
                    + BceidSoapClient.xml('clientKey', item.clientKey)
                    + BceidSoapClient.closeTag(
                        'AccountDetailListRequestItem'
                    );
            }
        }

        return x + BceidSoapClient.closeTag('requestItemList');
    }

    public class AccountDetailItem {
        public String userGuid;
        public String userId;
        public String accountTypeCode;
        public String clientKey;
    }

    public static String searchBceidAccount(
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        String sortDirection,
        String sortOnProperty,
        Integer pageSizeMaximum,
        Integer pageIndex,
        String searchableAccountType,
        String userIdValue,
        String userIdMatchUsing,
        String lastNameValue,
        String lastNameMatchUsing,
        Boolean includeBusinessMatch,
        Boolean doNotSearchBusiness
    ) {
        String x = BceidSoapClient.xml('onlineServiceId', onlineServiceId)
            + BceidSoapClient.xml(
                'requesterAccountTypeCode',
                requesterAccountTypeCode
            )
            + BceidSoapClient.xml('requesterUserGuid', requesterUserGuid)
            + BceidSoapClient.openTag('pagination')
            + BceidSoapClient.xmlInt('pageSizeMaximum', pageSizeMaximum)
            + BceidSoapClient.xmlInt('pageIndex', pageIndex)
            + BceidSoapClient.closeTag('pagination')
            + BceidSoapClient.openTag('sort')
            + BceidSoapClient.xml('direction', sortDirection)
            + BceidSoapClient.xml('onProperty', sortOnProperty)
            + BceidSoapClient.closeTag('sort')
            + BceidSoapClient.openTag('accountMatch')
            + buildMatch('userId', userIdValue, userIdMatchUsing)
            + buildMatch('lastName', lastNameValue, lastNameMatchUsing)
            + BceidSoapClient.xml(
                'searchableAccountType',
                searchableAccountType
            )
            + BceidSoapClient.closeTag('accountMatch');

        if (includeBusinessMatch) {
            x += BceidSoapClient.openTag('businessMatch')
                + BceidSoapClient.xml(
                    'searchableBusinessNumberVerified',
                    'DoNotSearch'
                )
                + BceidSoapClient.xml(
                    'searchableBusinessType',
                    'DoNotSearch'
                )
                + BceidSoapClient.xml(
                    'searchableBusinessState',
                    'DoNotSearch'
                )
                + BceidSoapClient.closeTag('businessMatch');
        }
        return x;
    }

    public static String searchInternalAccount(
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        String sortDirection,
        String sortOnProperty,
        Integer pageSizeMaximum,
        Integer pageIndex,
        String userIdValue,
        String userIdMatchUsing
    ) {
        return BceidSoapClient.xml('onlineServiceId', onlineServiceId)
            + BceidSoapClient.xml(
                'requesterAccountTypeCode',
                requesterAccountTypeCode
            )
            + BceidSoapClient.xml('requesterUserGuid', requesterUserGuid)
            + BceidSoapClient.openTag('pagination')
            + BceidSoapClient.xmlInt('pageSizeMaximum', pageSizeMaximum)
            + BceidSoapClient.xmlInt('pageIndex', pageIndex)
            + BceidSoapClient.closeTag('pagination')
            + BceidSoapClient.openTag('sort')
            + BceidSoapClient.xml('direction', sortDirection)
            + BceidSoapClient.xml('onProperty', sortOnProperty)
            + BceidSoapClient.closeTag('sort')
            + BceidSoapClient.openTag('accountMatch')
            + buildMatch('userId', userIdValue, userIdMatchUsing)
            + BceidSoapClient.closeTag('accountMatch');
    }

    public static String getSubscriptionCodeList(
        String onlineServiceId,
        String userGuid
    ) {
        return BceidSoapClient.xml('onlineServiceId', onlineServiceId)
            + BceidSoapClient.xml('userGuid', userGuid);
    }

    public static String getInternalUserGroupInfo(
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        String userGuid,
        List<GroupMatch> groups
    ) {
        String x = BceidSoapClient.xml('onlineServiceId', onlineServiceId)
            + BceidSoapClient.xml(
                'requesterAccountTypeCode',
                requesterAccountTypeCode
            )
            + BceidSoapClient.xml('requesterUserGuid', requesterUserGuid)
            + BceidSoapClient.xml('userGuid', userGuid)
            + BceidSoapClient.openTag('groupMatches');

        if (groups != null) {
            for (GroupMatch g : groups) {
                x += BceidSoapClient.openTag('BCeIDInternalGroupMatch')
                    + BceidSoapClient.xml('groupName', g.groupName)
                    + BceidSoapClient.xml('groupGuid', g.groupGuid)
                    + BceidSoapClient.closeTag('BCeIDInternalGroupMatch');
            }
        }
        return x + BceidSoapClient.closeTag('groupMatches');
    }

    public static String createSubscriptionBatch(
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        String batchDescription,
        String batchType,
        List<SubscriptionItem> subscriptions
    ) {
        String x = BceidSoapClient.xml('onlineServiceId', onlineServiceId)
            + BceidSoapClient.xml(
                'requesterAccountTypeCode',
                requesterAccountTypeCode
            )
            + BceidSoapClient.xml('requesterUserGuid', requesterUserGuid)
            + BceidSoapClient.openTag('batch')
            + BceidSoapClient.xml('description', batchDescription)
            + BceidSoapClient.xml('type', batchType)
            + '<v10:subscriptionList xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">';

        if (subscriptions != null) {
            for (SubscriptionItem s : subscriptions) {
                x += '<v10:anyType xsi:type="v10:BCeIDSubscription">'
                    + BceidSoapClient.xml('osKey', s.osKey)
                    + BceidSoapClient.xml('codeType', s.codeType)
                    + BceidSoapClient.xml('scope', s.scope)
                    + BceidSoapClient.xml('question', s.question)
                    + BceidSoapClient.xml('answer', s.answer)
                    + BceidSoapClient.openTag('account')
                    + BceidSoapClient.openTag('type')
                    + BceidSoapClient.xml(
                        'code',
                        s.accountTypeCode
                    )
                    + BceidSoapClient.closeTag('type')
                    + BceidSoapClient.closeTag('account')
                    + BceidSoapClient.xml(
                        'initialActivationPeriod',
                        String.valueOf(s.initialActivationPeriod)
                    )
                    + '</v10:anyType>';
            }
        }

        return x
            + '</v10:subscriptionList>'
            + BceidSoapClient.closeTag('batch');
    }

    public class GroupMatch {
        public String groupGuid;
        public String groupName;
    }

    public class SubscriptionItem {
        public String osKey;
        public String codeType;
        public String scope;
        public String question;
        public String answer;
        public String accountTypeCode;
        public Integer initialActivationPeriod;
    }

    private static String buildMatch(
        String tag,
        String value,
        String matchUsing
    ) {
        if (String.isBlank(value)) return '';
        return BceidSoapClient.openTag(tag)
            + BceidSoapClient.xml('value', value)
            + BceidSoapClient.xml('matchPropertyUsing', matchUsing)
            + BceidSoapClient.closeTag(tag);
    }
}