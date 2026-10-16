/** Apply BCeID person attributes to the linked User in a separate transaction. */
public with sharing class BceidUserUpdateJob implements Queueable {
    private Id userId;
    private String firstName;
    private String lastName;
    private String email;
    private String mobile;

    // Retain existing callers that update only the name.
    public BceidUserUpdateJob(Id userId, String firstName, String lastName) {
        this(userId, firstName, lastName, null, null);
    }

    public BceidUserUpdateJob(Id userId, String firstName, String lastName,
            String email, String mobile) {
        this.userId = userId;
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.mobile = mobile;
    }

    public void execute(QueueableContext context) {
        if (userId == null) return;
        List<User> matchingUsers = [
            SELECT Id, FirstName, LastName, Email, MobilePhone
            FROM User WHERE Id = :userId LIMIT 1
        ];
        if (matchingUsers.isEmpty()) return;
        User currentUser = matchingUsers[0];
        BceidPersonData data = new BceidPersonData(
            firstName, lastName, email, mobile);
        if (!BceidUserMapper.apply(currentUser, data)) return;

        try {
            SObjectAccessDecision accessDecision = Security.stripInaccessible(
                AccessType.UPDATABLE, new List<User>{ currentUser }
            );
            User sanitized = (User) accessDecision.getRecords()[0];
            update sanitized;
            System.debug(LoggingLevel.INFO, 'BCeID User person attributes updated.');
        } catch (DmlException e) {
            // User update must not interrupt completed Contact work or SSO.
            System.debug(LoggingLevel.ERROR,
                'BCeID User update failed. Status=' + e.getDmlStatusCode(0));
        }
    }
}
