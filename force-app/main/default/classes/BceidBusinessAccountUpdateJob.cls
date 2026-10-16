/**
 * Synchronizes BCeID business details after the registration-handler transaction.
 * Keeping Account DML separate from User DML avoids mixed-DML problems.
 * BCeID calls are NOT made again here; only already-verified data is passed in.
 */
public without sharing class BceidBusinessAccountUpdateJob implements Queueable {
    private Id userId;
    private BceidBusinessAccountMapper.BusinessData business;
    private Boolean configuredAccountActive; // Legacy constructor compatibility; existing Accounts always activate.

    // Retained for existing integrations and tests that do not supply a status.
    public BceidBusinessAccountUpdateJob(Id userId,
            BceidBusinessAccountMapper.BusinessData business) {
        this(userId, business, null);
    }

    public BceidBusinessAccountUpdateJob(Id userId,
            BceidBusinessAccountMapper.BusinessData business,
            Boolean configuredAccountActive) {
        this.userId = userId;
        this.business = business;
        this.configuredAccountActive = configuredAccountActive;
    }

    public void execute(QueueableContext context) {
        if (userId == null || business == null || String.isBlank(business.guid)) return;

        List<User> users = [SELECT Id, ContactId FROM User WHERE Id = :userId LIMIT 1];
        if (users.isEmpty() || users[0].ContactId == null) return;

        Id contactId = users[0].ContactId;
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE Id = :contactId LIMIT 1];
        if (contacts.isEmpty() || contacts[0].AccountId == null) return;

        syncLinkedAccount(contacts[0].AccountId, business, configuredAccountActive);
    }

    /**
     * Separated from relationship resolution so the actual Account security,
     * identity, comparison and DML paths can be tested with standard Accounts.
     * Never call this with an unverified Account Id from an external identity:
     * production entry is execute(), which resolves User -> Contact -> Account.
     */
    @TestVisible
    private static void syncLinkedAccount(Id accountId,
            BceidBusinessAccountMapper.BusinessData business) {
        syncLinkedAccount(accountId, business, null);
    }

    @TestVisible
    private static void syncLinkedAccount(Id accountId,
            BceidBusinessAccountMapper.BusinessData business,
            Boolean configuredAccountActive) {
        if (accountId == null || business == null || String.isBlank(business.guid)) return;
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Account.fields.getMap();
        List<String> columns = new List<String>{
            'Id', 'Name', 'Phone', 'BillingStreet', 'BillingCity', 'BillingPostalCode',
            'ShippingStreet', 'ShippingCity', 'ShippingPostalCode'
        };
        for (String optionalField : new List<String>{
            'BCeIDGUID__c', 'ExternalId__c', 'Doing_Business_As__c',
            // The canonical business number matches BceidBusinessAccountMapper.apply().
            'Tradestyle', 'BCeIDBusinessNumber__c', 'BillingCountry', 'BillingState',
            'ShippingCountry', 'ShippingState', 'BillingCountryCode', 'BillingStateCode',
            'ShippingCountryCode', 'ShippingStateCode'
        }) {
            if (fields.containsKey(optionalField) &&
                    fields.get(optionalField).getDescribe().isAccessible()) columns.add(optionalField);
        }
        // Status__c is optional in package target orgs. Only query it
        // if it is exposed to the executing user; update FLS is enforced below.
        if (fields.containsKey('Status__c') &&
                fields.get('Status__c').getDescribe().isAccessible()) {
            columns.add('Status__c');
        }
        // Avoid querying fields hidden by FLS in unlocked-package target orgs.
        List<String> readableColumns = new List<String>{ 'Id' };
        for (String col : columns) {
            if (col != 'Id' && fields.containsKey(col) &&
                    fields.get(col).getDescribe().isAccessible()) {
                readableColumns.add(col);
            }
        }
        columns = readableColumns;
        if (!columns.contains('BCeIDGUID__c') && !columns.contains('ExternalId__c')) {
            System.debug(LoggingLevel.WARN, 'BCeID Account sync skipped: no readable business identifier.');
            return;
        }
        List<Account> accounts;
        try {
            accounts = Database.query(
                'SELECT ' + String.join(columns, ',') + ' FROM Account WHERE Id = :accountId LIMIT 1'
            );
        } catch (QueryException e) {
            // Optional fields can be present in Describe but not queryable in
            // some unlocked-package target orgs; keep this job non-blocking.
            System.debug(LoggingLevel.ERROR,
                'BCeID Account sync skipped: Account fields could not be queried. ' + e.getMessage());
            return;
        }
        if (accounts.isEmpty()) return;

        Account current = accounts[0];
        // Preserve queried values so the DML payload can contain only changed
        // fields, rather than re-sending every selected field through triggers.
        Map<String, Object> originalValues = new Map<String, Object>();
        for (String column : columns) {
            if (column != 'Id') originalValues.put(column, current.get(column));
        }
        Boolean identityMatch = false;
        for (String idField : new List<String>{ 'BCeIDGUID__c', 'ExternalId__c' }) {
            if (!columns.contains(idField)) continue;
            String currentGuid = (String) current.get(idField);
            if (String.isNotBlank(currentGuid) &&
                    !currentGuid.equalsIgnoreCase(business.guid)) {
                System.debug(LoggingLevel.WARN, 'BCeID Account sync skipped: business GUID mismatch.');
                return;
            }
            if (String.isNotBlank(currentGuid)) identityMatch = true;
        }
        if (!identityMatch) {
            System.debug(LoggingLevel.WARN, 'BCeID Account sync skipped: no verified matching business identifier.');
            return;
        }
        Boolean changed = BceidBusinessAccountMapper.apply(current, business);
        // A verified BCeID business Account must have Status__c = Active.
        // Never update status for an unverified business GUID.
        if (columns.contains('Status__c') &&
                fields.get('Status__c').getDescribe().isUpdateable()) {
            String currentStatus = (String) current.get('Status__c');
            if (currentStatus != 'Active') {
                current.put('Status__c', 'Active');
                changed = true;
            }
        }
        if (!changed) {
            System.debug(LoggingLevel.INFO, 'BCeID Account already matches; no DML.');
            return;
        }

        // Apply only changed fields; avoid touching unaffected Account fields.
        Account changes = new Account(Id = accountId);
        for (String column : columns) {
            if (column == 'Id') continue;
            Object prior = originalValues.get(column);
            Object nextValue = current.get(column);
            if (prior == null && nextValue == null) continue;
            if (prior != null && String.valueOf(prior) == String.valueOf(nextValue)) continue;
            changes.put(column, nextValue);
        }
        Account sanitized = (Account) Security.stripInaccessible(
            AccessType.UPDATABLE, new List<Account>{ changes }
        ).getRecords()[0];
        if (sanitized.getPopulatedFieldsAsMap().size() <= 1) {
            System.debug(LoggingLevel.WARN,
                'BCeID Account sync skipped: changed fields are not updateable.');
            return;
        }
        try {
            update sanitized;
        } catch (DmlException e) {
            // Business sync should not invalidate a completed login.
            System.debug(LoggingLevel.ERROR,
                'BCeID Account sync update failed. Status=' + e.getDmlStatusCode(0));
        }
    }
}
