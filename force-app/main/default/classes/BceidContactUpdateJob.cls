public without sharing class BceidContactUpdateJob implements Queueable {
    private Id contactId;
    private Id userId;
    private String firstName;
    private String lastName;
    private Boolean queueUserUpdate;

    public BceidContactUpdateJob(
        Id contactId,
        Id userId,
        String firstName,
        String lastName,
        Boolean queueUserUpdate
    ) {
        this.contactId = contactId;
        this.userId = userId;
        this.firstName = firstName;
        this.lastName = lastName;
        this.queueUserUpdate = queueUserUpdate == true;
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

        if (users.isEmpty() || users[0].ContactId != contactId) {
            System.debug(
                LoggingLevel.ERROR,
                'BCeID Contact update rejected because Contact ' + contactId +
                ' is not associated with User ' + userId + '.'
            );
            return;
        }

        List<Contact> contacts = [
            SELECT Id, FirstName, LastName
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

        if (currentContact.FirstName != firstName ||
            currentContact.LastName != lastName) {

            currentContact.FirstName = firstName;
            currentContact.LastName = lastName;

            try {
                update currentContact;

                System.debug(
                    LoggingLevel.INFO,
                    'BCeID Contact name updated successfully for Contact ' +
                    contactId + '.'
                );
            } catch (DmlException e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'BCeID Contact name update failed for Contact ' +
                    contactId + ': ' + e.getMessage()
                );
                return;
            }
        } else {
            System.debug(
                LoggingLevel.INFO,
                'BCeID Contact name already matches for Contact ' +
                contactId + '; no Contact DML required.'
            );
        }

        // Queue User DML only after the Contact transaction has completed its
        // Contact work. This keeps User and Contact DML in separate transactions.
        if (queueUserUpdate) {
            Id userJobId = System.enqueueJob(
                new BceidUserUpdateJob(userId, firstName, lastName)
            );

            System.debug(
                LoggingLevel.INFO,
                'BCeID User update queued after Contact processing. Job Id=' +
                userJobId + ', User Id=' + userId
            );
        }
    }
}