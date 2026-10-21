/**
 * @description       : 
 * @author            : Roy Poystila
 * @group             : 
 * @last modified on  : 09-29-2026
 * @last modified by  : Roy Poystila
**/
public without sharing class BceidContactUpdateJob implements Queueable {
    private Id contactId;
    private Id userId;
    private String firstName;
    private String lastName;
    private String email;
    private String mobile;
    private Boolean queueUserUpdate;
    private Boolean bypassRelationshipValidationForTest;
    private BceidBusinessAccountMapper.BusinessData business;

    public BceidContactUpdateJob(
        Id contactId,
        Id userId,
        String firstName,
        String lastName,
        Boolean queueUserUpdate
    ) {
        this(contactId, userId, firstName, lastName,
            null, null, queueUserUpdate, false, null);
    }

    /** New constructor: map names, email and mobile; optionally chain User DML. */
    public BceidContactUpdateJob(Id contactId, Id userId,
            String firstName, String lastName, String email, String mobile,
            Boolean queueUserUpdate) {
        this(contactId, userId, firstName, lastName, email, mobile,
            queueUserUpdate, false, null);
    }

    /** Full payload constructor used by registration and login synchronization. */
    public BceidContactUpdateJob(Id contactId, Id userId,
            String firstName, String lastName, String email, String mobile,
            Boolean queueUserUpdate, BceidBusinessAccountMapper.BusinessData business) {
        this(contactId, userId, firstName, lastName, email, mobile,
            queueUserUpdate, false, business);
    }

    @TestVisible
    private BceidContactUpdateJob(Id contactId, Id userId,
            String firstName, String lastName, Boolean queueUserUpdate,
            Boolean bypassRelationshipValidationForTest) {
        this(contactId, userId, firstName, lastName, null, null,
            queueUserUpdate, bypassRelationshipValidationForTest, null);
    }

    @TestVisible
    private BceidContactUpdateJob(Id contactId, Id userId,
            String firstName, String lastName, String email, String mobile,
            Boolean queueUserUpdate, Boolean bypassRelationshipValidationForTest) {
        this(contactId, userId, firstName, lastName, email, mobile,
            queueUserUpdate, bypassRelationshipValidationForTest, null);
    }

    @TestVisible
    private BceidContactUpdateJob(
        Id contactId,
        Id userId,
        String firstName,
        String lastName,
        String email,
        String mobile,
        Boolean queueUserUpdate,
        Boolean bypassRelationshipValidationForTest,
        BceidBusinessAccountMapper.BusinessData business
    ) {
        this.contactId = contactId;
        this.userId = userId;
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.mobile = mobile;
        this.queueUserUpdate = queueUserUpdate == true;
        this.bypassRelationshipValidationForTest =
            bypassRelationshipValidationForTest == true;
        this.business = business;
    }

    public void execute(QueueableContext context) {
        if (contactId == null || userId == null) {
            System.debug(
                LoggingLevel.WARN,
                'BCeID Contact update skipped because Contact Id or User Id is null.'
            );
            return;
        }

        Boolean hasPersonData = String.isNotBlank(firstName) ||
            String.isNotBlank(lastName) || String.isNotBlank(email) ||
            String.isNotBlank(mobile);
        Boolean hasBusinessData = business != null && String.isNotBlank(business.guid);
        if (!hasPersonData && !hasBusinessData) {
            System.debug(LoggingLevel.WARN,
                'BCeID synchronization skipped because no authorized person or business fields were returned.');
            return;
        }

        // Revalidate the User -> Contact relationship in this elevated
        // transaction before performing Contact DML.
        List<User> users = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        if (users.isEmpty() ||
            (users[0].ContactId != contactId &&
             !(Test.isRunningTest() && bypassRelationshipValidationForTest))) {
            System.debug(
                LoggingLevel.ERROR,
                'BCeID Contact update rejected because Contact ' + contactId +
                ' is not associated with User ' + userId + '.'
            );
            return;
        }

        List<Contact> contacts = [
            SELECT Id, AccountId, FirstName, LastName, Email, MobilePhone
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        if (contacts.isEmpty()) {
            System.debug(
                LoggingLevel.WARN,
                'BCeID Contact update skipped because Contact ' + contactId +
                ' was not found.'
            );
            return;
        }

        Contact currentContact = contacts[0];
        Map<String, Object> priorValues = new Map<String, Object>{
            'FirstName' => currentContact.FirstName,
            'LastName' => currentContact.LastName,
            'Email' => currentContact.Email,
            'MobilePhone' => currentContact.MobilePhone
        };
        BceidPersonData person = new BceidPersonData(
            firstName, lastName, email, mobile);
        if (BceidContactMapper.apply(currentContact, person)) {
            try {
                // Send a sparse update containing only changed mapped fields. This
                // avoids retriggering automation with stale values for unrelated fields.
                Contact proposedChanges = new Contact(Id = contactId);
                for (String fieldName : new List<String>{
                    'FirstName', 'LastName', 'Email', 'MobilePhone'
                }) {
                    Object priorValue = priorValues.get(fieldName);
                    Object nextValue = currentContact.get(fieldName);
                    if (priorValue == null && nextValue == null) continue;
                    if (priorValue != null && String.valueOf(priorValue) == String.valueOf(nextValue)) continue;
                    proposedChanges.put(fieldName, nextValue);
                }
                SObjectAccessDecision accessDecision = Security.stripInaccessible(
                    AccessType.UPDATABLE, new List<Contact>{ proposedChanges }
                );
                Contact sanitized = (Contact) accessDecision.getRecords()[0];
                if (sanitized.getPopulatedFieldsAsMap().size() > 1) {
                    update sanitized;
                    System.debug(LoggingLevel.INFO,
                        'BCeID Contact changed fields updated for linked Contact.');
                } else {
                    System.debug(LoggingLevel.WARN,
                        'BCeID Contact fields were not updateable in the executing context.');
                }
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR,
                    'BCeID Contact update failed. Status=' +
                    e.getDmlStatusCode(0));
                // Contact failure must not suppress independent User and Account
                // updates from the same successful, authorized BCeID response.
            }
        } else {
            System.debug(LoggingLevel.INFO,
                'BCeID Contact values already match or were empty; no DML.');
        }

        // Publish a platform event instead of chaining another Queueable.
        // Contact automation can already consume Queueable depth; the event
        // subscriber runs in a separate transaction and performs User DML there.
        if (queueUserUpdate) {
            Bceid_User_Update_Request__e updateRequest =
                new Bceid_User_Update_Request__e(
                    UserId__c = String.valueOf(userId),
                    FirstName__c = firstName,
                    LastName__c = lastName,
                    Email__c = email,
                    MobilePhone__c = mobile
                );

            Database.SaveResult publishResult = EventBus.publish(updateRequest);
            if (publishResult.isSuccess()) {
                System.debug(LoggingLevel.INFO,
                    'BCeID User update request published for User ' + userId + '.');
            } else {
                for (Database.Error publishError : publishResult.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'BCeID User update request could not be published. Status=' +
                        publishError.getStatusCode());
                }
            }
        }

        // Account and Contact are both non-setup records, so update the verified
        // linked Account in this same Queueable. This avoids chaining another
        // Queueable (which can hit stack depth when org automation also queues work).
        if (business != null && String.isNotBlank(business.guid) &&
                contacts[0].AccountId != null) {
            try {
                BceidBusinessAccountUpdateJob.syncLinkedAccountFromVerifiedContact(
                    contacts[0].AccountId, business);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'BCeID Account update failed for linked Contact ' + contactId +
                    ': ' + e.getMessage());
            }
        }
    }
}