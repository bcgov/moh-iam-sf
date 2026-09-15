public without sharing class BceidUserUpdateJob implements Queueable {
    private Id userId;
    private String firstName;
    private String lastName;

    public BceidUserUpdateJob(Id userId, String firstName, String lastName) {
        this.userId = userId;
        this.firstName = firstName;
        this.lastName = lastName;
    }

    public void execute(QueueableContext context) {
        if (userId == null || String.isBlank(firstName) || String.isBlank(lastName)) {
            System.debug(
                LoggingLevel.WARN,
                'BCeID User update skipped because required input is missing.'
            );
            return;
        }

        List<User> users = [
            SELECT Id, FirstName, LastName
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        if (users.isEmpty()) {
            System.debug(
                LoggingLevel.WARN,
                'BCeID User update skipped because User ' + userId + ' was not found.'
            );
            return;
        }

        User currentUser = users[0];

        if (currentUser.FirstName == firstName &&
            currentUser.LastName == lastName) {
            System.debug(
                LoggingLevel.INFO,
                'BCeID User name already matches for User ' + userId +
                '; no User DML required.'
            );
            return;
        }

        currentUser.FirstName = firstName;
        currentUser.LastName = lastName;

        try {
            update currentUser;

            System.debug(
                LoggingLevel.INFO,
                'BCeID User name updated successfully for User ' + userId + '.'
            );
        } catch (DmlException e) {
            System.debug(
                LoggingLevel.ERROR,
                'BCeID User name update failed for User ' +
                userId + ': ' + e.getMessage()
            );
        }
    }
}