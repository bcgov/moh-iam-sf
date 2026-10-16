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

    public BceidContactUpdateJob(
        Id contactId,
        Id userId,
        String firstName,
        String lastName,
        Boolean queueUserUpdate
    ) {
        this(contactId, userId, firstName, lastName,
            null, null, queueUserUpdate, false);
    }

    /** New constructor: map names, email and mobile; optionally chain User DML. */
    public BceidContactUpdateJob(Id contactId, Id userId,
            String firstName, String lastName, String email, String mobile,
            Boolean queueUserUpdate) {
        this(contactId, userId, firstName, lastName, email, mobile,
            queueUserUpdate, false);
    }

    @TestVisible
    private BceidContactUpdateJob(Id contactId, Id userId,
            String firstName, String lastName, Boolean queueUserUpdate,
            Boolean bypassRelationshipValidationForTest) {
        this(contactId, userId, firstName, lastName, null, null,
            queueUserUpdate, bypassRelationshipValidationForTest);
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
        Boolean bypassRelationshipValidationForTest
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
    }

    public void execute(QueueableContext context) {
        if (contactId == null || userId == null) {
            System.debug(
                LoggingLevel.WARN,
                'BCeID Contact update skipped because Contact Id or User Id is null.'
            );
            return;
        }

        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            System.debug(
                LoggingLevel.WARN,
                'BCeID Contact update skipped because first or last name is blank.'
            );
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
            SELECT Id, FirstName, LastName, Email, MobilePhone
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
        BceidPersonData person = new BceidPersonData(
            firstName, lastName, email, mobile);
        if (BceidContactMapper.apply(currentContact, person)) {
            try {
                // Retain only the fields the executing context can update.
                SObjectAccessDecision accessDecision = Security.stripInaccessible(
                    AccessType.UPDATABLE, new List<Contact>{ currentContact }
                );
                Contact sanitized = (Contact) accessDecision.getRecords()[0];
                update sanitized;
                System.debug(LoggingLevel.INFO,
                    'BCeID Contact fields updated for linked Contact.');
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR,
                    'BCeID Contact update failed. Status=' +
                    e.getDmlStatusCode(0));
                return;
            }
        } else {
            System.debug(LoggingLevel.INFO,
                'BCeID Contact values already match or were empty; no DML.');
        }

        // Queue User DML only after the Contact transaction has completed its
        // Contact work. This keeps User and Contact DML in separate transactions.
        if (queueUserUpdate) {
            Id userJobId = System.enqueueJob(
                new BceidUserUpdateJob(userId, firstName, lastName, email, mobile)
            );

            System.debug(
                LoggingLevel.INFO,
                'BCeID User update queued after Contact processing. Job Id=' +
                userJobId + ', User Id=' + userId
            );
        }
    }
}