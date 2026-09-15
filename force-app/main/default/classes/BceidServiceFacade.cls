public with sharing class BceidServiceFacade {
    public static BceidSoapClient.SoapResult getAccountDetail(
        BceidConfig cfg,
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserId,
        String requesterUserGuid,
        String userId,
        String userGuid,
        String accountTypeCode
    ) {
        String payload =
            BceidSoapClient.openTag('accountDetailRequest')
            + BceidRequestBuilders.getAccountDetail(
                onlineServiceId,
                requesterAccountTypeCode,
                requesterUserId,
                requesterUserGuid,
                userId,
                userGuid,
                accountTypeCode
            )
            + BceidSoapClient.closeTag('accountDetailRequest');

        return BceidSoapClient.invoke(
            cfg,
            'getAccountDetail',
            payload
        );
    }

    // Compatibility overload matching the original method signature.
    public static BceidSoapClient.SoapResult getAccountDetail(
        BceidConfig cfg,
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        String userGuid,
        String userId,
        String accountTypeCode
    ) {
        return getAccountDetail(
            cfg,
            onlineServiceId,
            requesterAccountTypeCode,
            '',
            requesterUserGuid,
            userId,
            userGuid,
            accountTypeCode
        );
    }

    public static BceidSoapClient.SoapResult getAccountDetailList(
        BceidConfig cfg,
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        List<BceidRequestBuilders.AccountDetailItem> items
    ) {
        String payload =
            BceidSoapClient.openTag('accountDetailListRequest')
            + BceidRequestBuilders.getAccountDetailList(
                onlineServiceId,
                requesterAccountTypeCode,
                requesterUserGuid,
                items
            )
            + BceidSoapClient.closeTag('accountDetailListRequest');

        return BceidSoapClient.invoke(cfg, 'getAccountDetailList', payload);
    }

    public static BceidSoapClient.SoapResult searchBceIDAccount(
        BceidConfig cfg,
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
        String lastNameMatchUsing
    ) {
        String payload =
            BceidSoapClient.openTag('bceidAccountSearchRequest')
            + BceidRequestBuilders.searchBceidAccount(
                onlineServiceId,
                requesterAccountTypeCode,
                requesterUserGuid,
                sortDirection,
                sortOnProperty,
                pageSizeMaximum,
                pageIndex,
                searchableAccountType,
                userIdValue,
                userIdMatchUsing,
                lastNameValue,
                lastNameMatchUsing,
                false,
                true
            )
            + BceidSoapClient.closeTag('bceidAccountSearchRequest');

        return BceidSoapClient.invoke(cfg, 'searchBCeIDAccount', payload);
    }

    public static BceidSoapClient.SoapResult searchInternalAccount(
        BceidConfig cfg,
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
        String payload =
            BceidSoapClient.openTag('internalAccountSearchRequest')
            + BceidRequestBuilders.searchInternalAccount(
                onlineServiceId,
                requesterAccountTypeCode,
                requesterUserGuid,
                sortDirection,
                sortOnProperty,
                pageSizeMaximum,
                pageIndex,
                userIdValue,
                userIdMatchUsing
            )
            + BceidSoapClient.closeTag('internalAccountSearchRequest');

        return BceidSoapClient.invoke(cfg, 'searchInternalAccount', payload);
    }

    public static BceidSoapClient.SoapResult getSubscriptionCodeList(
        BceidConfig cfg,
        String onlineServiceId,
        String userGuid
    ) {
        String payload =
            BceidSoapClient.openTag('subscriptionCodeListRequest')
            + BceidRequestBuilders.getSubscriptionCodeList(
                onlineServiceId,
                userGuid
            )
            + BceidSoapClient.closeTag('subscriptionCodeListRequest');

        return BceidSoapClient.invoke(
            cfg,
            'getSubscriptionCodeList',
            payload
        );
    }

    public static BceidSoapClient.SoapResult getInternalUserGroupInfo(
        BceidConfig cfg,
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        String userGuid,
        List<BceidRequestBuilders.GroupMatch> groups
    ) {
        String payload =
            BceidSoapClient.openTag('internalUserGroupInfoRequest')
            + BceidRequestBuilders.getInternalUserGroupInfo(
                onlineServiceId,
                requesterAccountTypeCode,
                requesterUserGuid,
                userGuid,
                groups
            )
            + BceidSoapClient.closeTag('internalUserGroupInfoRequest');

        return BceidSoapClient.invoke(
            cfg,
            'getInternalUserGroupInfo',
            payload
        );
    }

    public static BceidSoapClient.SoapResult createSubscriptionBatch(
        BceidConfig cfg,
        String onlineServiceId,
        String requesterAccountTypeCode,
        String requesterUserGuid,
        String batchDescription,
        String batchType,
        List<BceidRequestBuilders.SubscriptionItem> subscriptions
    ) {
        String payload =
            BceidSoapClient.openTag('createSubscriptionBatchRequest')
            + BceidRequestBuilders.createSubscriptionBatch(
                onlineServiceId,
                requesterAccountTypeCode,
                requesterUserGuid,
                batchDescription,
                batchType,
                subscriptions
            )
            + BceidSoapClient.closeTag('createSubscriptionBatchRequest');

        return BceidSoapClient.invoke(
            cfg,
            'createSubscriptionBatch',
            payload
        );
    }
}