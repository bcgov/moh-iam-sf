public with sharing class UserRegistrationBetaUser {
    public class UserVariables {
        @InvocableVariable
        public List<User> userIdentifiers;
    }

    public class ResultVariables {
        @InvocableVariable
        public List<String> BetaUsers;
    }

    @InvocableMethod (label='Process Beta Users' description='Process Beta Users')
    public static List<ResultVariables> applyBetaUsers(List<UserVariables> userVariables)
    {
        List<User> userList =  userVariables.get(0).userIdentifiers;
        List<User> updateUserList = new List<User>();
        Boolean isEnforceBetauser = false;

        List<ResultVariables> results = new List<ResultVariables>();
        ResultVariables result = new ResultVariables();
        result.BetaUsers = new List<String>();
        // check if beta user restriction is in place
        for (User checkUser: userList)
        {
            if (String.isNotEmpty(checkUser.User_Provisioning_Role__c))
            {

                UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility(checkUser.User_Provisioning_Role__c);
                String assignedRole = checkUser.User_Provisioning_Role__c;
                List<IDP_User_Registration_User_Mapping__mdt>  userRoleList = new List<IDP_User_Registration_User_Mapping__mdt>();
                userRoleList.addAll(processRoles.ReadMapping(checkUser.User_Provisioning_Role__c));
                for (IDP_User_Registration_User_Mapping__mdt  userBeta: userRoleList)
                {
                    if (userBeta.is_Restrict_Beta_User_Only__c == true)
                    {
                        isEnforceBetauser = true;
                    }           
                }
            }
        }
        System.debug('userList: ' + userList);
        System.debug('getAuthority(): ' + URL.getCurrentRequestUrl().getHost());
        String currentHost = URL.getCurrentRequestUrl().getHost();
        if ((currentHost.toLowerCase().contains('healthgateway') && isEnforceBetauser) || Test.isRunningTest())
        {
            try {
                Boolean checkBetaUser = UserRegistrationPermission.checkIsBetaUser(userList);
                if (checkBetaUser)
                {
                    for (User updateUserToBeta: userList)
                    {
                        User userUpdate = new User();
                        userUpdate.Id = updateUserToBeta.Id;
                        userUpdate.User_Provisioning_Role__c = 'BETA';
                        updateUserList.add(userUpdate);
                    }
                    update updateUserList;
                } else {
                    UnexpectedException e = new UnexpectedException();
                    e.setMessage('You are not a Beta User.');
                    throw e;
                }
            } catch (Exception e) {
                System.debug('applyBetaUsers: ' + e.getMessage());
            }
        }

        List<String> addedBetaUsers = new List<String>();

        List<ResultVariables> returnVarsList = new List<ResultVariables>();
        ResultVariables returnVars = new ResultVariables();
        returnVars.BetaUsers = addedBetaUsers;
        returnVarsList.add(returnVars);
        return returnVarsList;
    }
}