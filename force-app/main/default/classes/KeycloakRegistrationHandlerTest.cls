@isTest
public class KeycloakRegistrationHandlerTest {
  private static final String OAUTH_TOKEN = 'testToken';
  private static final String STATE = 'mocktestState';
  private static final String REFRESH_TOKEN = 'refreshToken';
  private static final String LOGIN_ID = 'testLoginId';
  private static final String USERNAME = 'testUsername';
  private static final String FIRST_NAME = 'testFirstName';
  private static final String LAST_NAME = 'testLastName';
  private static final String EMAIL_ADDRESS = 'testEmailAddress';
  private static final String LOCALE_NAME = 'testLocalName';
  private static final String FULL_NAME = FIRST_NAME + ' ' + LAST_NAME;
  private static final String PROVIDER = 'Concur';
  private static final String REDIRECT_URL = 'http://localhost/services/authcallback/orgId/Concur';
  private static final String KEY = 'testKey';
  private static final String SECRET = 'testSecret';
  private static final String STATE_TO_PROPOGATE = 'testState';
  private static final String ACCESS_TOKEN_URL = 'http://www.dummyhost.com/accessTokenUri';
  private static final String API_USER_VERSION_URL = 'http://www.dummyhost.com/user/20/1';
  private static final String AUTH_URL = 'http://www.dummy.com/authurl';
  private static final String API_USER_URL = 'www.concursolutions.com/user/api';
  private static User RUN_TIME_USER = new User();
  private static Boolean ACCOUNT_HDID_EXISTS = false;

  private static Map<String, String> setupAuthProviderConfig() {
      Map<String, String> authProviderConfiguration = new Map<String, String>();
      authProviderConfiguration.put('Key__c', KEY);
      authProviderConfiguration.put('Auth_Url__c', AUTH_URL);
      authProviderConfiguration.put('Secret__c', SECRET);
      authProviderConfiguration.put('Access_Token_Url__c', ACCESS_TOKEN_URL);
      authProviderConfiguration.put('API_User_Url__c', API_USER_URL);
      authProviderConfiguration.put(
        'API_User_Version_Url__c',
        API_USER_VERSION_URL
      );
      authProviderConfiguration.put('Redirect_Url__c', REDIRECT_URL);
      return authProviderConfiguration;
  }

  @TestSetup
  public static void testSetup() {

    test.startTest();
        verifyTestUser();
    test.stopTest();

    PermissionSetGroup psg = [select Id, Status from PermissionSetGroup where DeveloperName='TESTONLY_DONOTREMOVE'];
    
    // force calculation of the PSG if it is not already Updated
    if (psg.Status != 'Updated') {
      Test.calculatePermissionSetGroup(psg.Id);
    }
    UserRegistrationCustomMetadataUtility utilityChecks = new UserRegistrationCustomMetadataUtility();
    if (utilityChecks.isFieldExisting('HDID__c', 'Account'))
    {
        ACCOUNT_HDID_EXISTS = true;
    } 

    User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
    System.runAs(runtimeUser) {   

        Profile commUserType = [
            SELECT Id, Name, UserType 
            FROM Profile 
            WHERE Name = 'Customer Community Plus Login User' Limit 1];  

        Account newPersonAccount0 = new Account();    
        Account newPersonAccount = new Account();
        List<Account> newPersonAccounts = new List<Account>();
        String setIdentifier = '';

        Id personAccountRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        newPersonAccount0.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount0.FirstName = 'TESTONLY_ZERO';
        newPersonAccount0.LastName = 'TESTONLY_LAST';
        newPersonAccount0.PersonEmail = 'TESTONLY0@EMAIL.com';
        newPersonAccount0.SourceSystemIdentifier = 'CPN.TSTP00000.CPSID.GS';
        newPersonAccount0.HealthCloudGA__SourceSystemId__pc = 'CPN.TSTP00000.CPSID.GS';
        newPersonAccount0.isActive = true;
        //setIdentifier = (String)newPersonAccount0.put('HealthCloudGA__SourceSystemId__pc', 'CPN.TSTP00000.CPSID.GS');
        if (ACCOUNT_HDID_EXISTS)
        {
            newPersonAccount0.put('HDID__c', 'newPersonAccount0');
        } else {
            newPersonAccount0.put('AccountNumber', 'newPersonAccount0');
        }
        
        newPersonAccounts.Add(newPersonAccount0);
        
        newPersonAccount.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount.FirstName = 'TESTONLY_FIRST';
        newPersonAccount.LastName = 'TESTONLY_LAST';
        newPersonAccount.PersonEmail = 'TESTONLY@EMAIL.com';
        newPersonAccount.SourceSystemIdentifier = 'CPN.TSTP00015.CPSID.GS';
        newPersonAccount.HealthCloudGA__SourceSystemId__pc = 'CPN.TSTP00015.CPSID.GS';
        newPersonAccount.isActive = true;
        //setIdentifier = (String)newPersonAccount.put('HealthCloudGA__SourceSystemId__pc', 'CPN.TSTP00015.CPSID.GS');
        if (ACCOUNT_HDID_EXISTS)
        {
            newPersonAccount.put('HDID__c', 'newPersonAccount');
        } else {
            newPersonAccount.put('AccountNumber', 'newPersonAccount');
        }

        newPersonAccounts.Add(newPersonAccount);
        
        Account newPersonAccount3 = new Account();
        newPersonAccount3.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount3.FirstName = 'TESTONLYBCSC3_FIRST';
        newPersonAccount3.LastName = 'TESTONLYBCSC3_LAST';
        newPersonAccount3.PersonEmail = 'testusername3@me.com';
        newPersonAccount3.SourceSystemIdentifier = 'CPN.TSTP00016.CPSID.GS';
        newPersonAccount3.HealthCloudGA__SourceSystemId__pc = 'CPN.TSTP00016.CPSID.GS';
        newPersonAccount3.isActive = true;
        //setIdentifier = (String)newPersonAccount3.put('HealthCloudGA__SourceSystemId__pc', 'CPN.TSTP00016.CPSID.GS');
        if (ACCOUNT_HDID_EXISTS)
        {
            newPersonAccount3.put('HDID__c', 'newPersonAccount3');
        } else {
            newPersonAccount3.put('AccountNumber', 'newPersonAccount3');
        }
        
        newPersonAccounts.Add(newPersonAccount3);

        Account newPersonAccount2 = new Account();
        newPersonAccount2.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount2.FirstName = 'TESTONLYBCSC2_FIRST';
        newPersonAccount2.LastName = 'TESTONLYBCSC2_LAST';
        newPersonAccount2.PersonEmail = 'TESTONLYBCSC2@EMAIL.com';
        newPersonAccount2.SourceSystemIdentifier = 'GUID01';
        newPersonAccount2.HealthCloudGA__SourceSystemId__pc = 'GUID01';
        newPersonAccount2.isActive = true;
        //setIdentifier = (String)newPersonAccount2.put('HealthCloudGA__SourceSystemId__pc', 'GUID01');
        if (ACCOUNT_HDID_EXISTS)
        {
            newPersonAccount2.put('HDID__c', 'newPersonAccount2');
        } else {
            newPersonAccount2.put('AccountNumber', 'newPersonAccount2');
        }

        newPersonAccounts.Add(newPersonAccount2);        

        Account newPersonAccount4 = new Account();
        newPersonAccount4.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount4.FirstName = 'TESTONLYBCSC4_FIRST';
        newPersonAccount4.LastName = 'TESTONLYBCSC4_LAST';
        newPersonAccount4.PersonEmail = 'TESTONLYBCSC4@EMAIL.com';
        newPersonAccount4.SourceSystemIdentifier = 'newPersonAccount4';
        newPersonAccount4.HealthCloudGA__SourceSystemId__pc = 'newPersonAccount4';
        newPersonAccount4.isActive = true;
        //setIdentifier = (String)newPersonAccount4.put('HealthCloudGA__SourceSystemId__pc', 'GUID02');
        if (ACCOUNT_HDID_EXISTS)
        {
            newPersonAccount4.put('HDID__c', 'newPersonAccount4');
        } else {
            newPersonAccount4.put('AccountNumber', 'newPersonAccount4');
        }

        newPersonAccounts.Add(newPersonAccount4);  

        Account newPersonAccount5 = new Account();
        newPersonAccount5.RecordTypeId = personAccountRecordTypeId;
        newPersonAccount5.FirstName = 'TESTONLYBCSC5_FIRST';
        newPersonAccount5.LastName = 'TESTONLYBCSC5_LAST';
        newPersonAccount5.PersonEmail = 'TESTONLYBCSC5@EMAIL.com';
        newPersonAccount5.SourceSystemIdentifier = 'newPersonAccount5';
        newPersonAccount5.isActive = true;
        //setIdentifier = (String)newPersonAccount4.put('HealthCloudGA__SourceSystemId__pc', 'GUID02');
        if (ACCOUNT_HDID_EXISTS)
        {
            newPersonAccount5.put('HDID__c', 'newPersonAccount5');
        } else {
            newPersonAccount5.put('AccountNumber', 'newPersonAccount5');
        }

        newPersonAccounts.Add(newPersonAccount5);      

        insert newPersonAccounts;
        
        Account fetchAccount = [
            SELECT Id, PersonContactId 
            FROM Account 
            WHERE PersonEmail = 'TESTONLY0@EMAIL.com'];        

        Group testGroup = new Group();
        testGroup.Name = 'Test_Group';
        insert testGroup;    
    }
  }

  @isTest
    public static void testUpdateCommunityeUser() {
    String uniqueUserName =
        'standarduser' +
        DateTime.now().getTime() +
        '@testorg.com';

    List<UserRole> userRole = [SELECT Id FROM UserRole];
    String userRoleId = userRole[0].Id;
    KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();

    Map<String,String> attribmap = new Map<String,String>();
    attribmap.put('roles', 'BCSC_TESTONLY');
    attribmap.put('pidp_email', 'moa11@phsa.ca');
    attribmap.put('given_name', 'testFirst');
    attribmap.put('family_name', 'testLast');
    attribmap.put('email', 'pidp.eleven9@bcprovinderstaging.onmicrosoft.com');
    attribmap.put('preferred_username', 'pidp.eleven9@bcproviderstaging.onmicrosoft.com@bcp');
    attribmap.put('name', 'testFirst testLast');

    Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        null,
        'testuserlong',
        'en_US',
        'facebook',
        null,
        attribmap
    );
    System.debug('sampleData:' + sampleData);
        test.startTest();
            verifyTestUser();
        test.stopTest();
        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {

            User u = handler.createUser(null, sampleData);
            System.assertEquals('testLast', u.lastName);
            System.assertEquals('testFirst', u.firstName);
            List<Auth.UserData> users = new List<Auth.UserData>();
            List<Id> ids = new List<Id>(); 
            ids.add(u.Id);
            users.add(sampleData);
            handler.updateUser(u.Id, null, sampleData);
            String uid = u.id;
            List<User> processUserList = [SELECT Id, Name, FirstName, LastName, User_Provisioning_Role__c FROM USER WHERE Id =: u.id Limit 1];
            // Test Permission callout
             try {
                List<UserRegistrationPermission.InputVariables> processInput = new List<UserRegistrationPermission.InputVariables>();
                UserRegistrationPermission.InputVariables userInput = new UserRegistrationPermission.InputVariables();

                userInput.userPerms = processUserList;
                processInput.add(userInput);
                System.debug('processInput.size: ' + processInput.size());
                UserRegistrationPermission.applyPermissions(processInput);

                
            } catch (Exception e) {
                System.debug('applyPermissions: ' + e.getMessage());
            } 
            
        }
  
  }

  @isTest
    public static void testUpdateCommunityUser() {
    String uniqueUserName =
        'standarduser' +
        DateTime.now().getTime() +
        '@testorg.com';

    List<UserRole> userRole = [SELECT Id FROM UserRole];
    String userRoleId = userRole[0].Id;
    KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();

    Map<String,String> attribmap = new Map<String,String>();
    attribmap.put('roles', 'BCSC_TESTONLY');
    attribmap.put('pidp_email', 'moa11@phsa.ca');
    attribmap.put('given_name', 'testFirst');
    attribmap.put('family_name', 'testLast');
    attribmap.put('email', 'TESTONLYBCSC5@EMAIL.com');
    attribmap.put('personemail', 'TESTONLYBCSC5@EMAIL.com');
    attribmap.put('preferred_username', 'pidp.eleven9@bcproviderstaging.onmicrosoft.com@bcp');
    attribmap.put('name', 'testFirst testLast');
    attribmap.put('hdid', 'newPersonAccount5');
    attribmap.put('idp', 'BCSC_TESTONLY');

    Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        null,
        'testuserlong',
        'en_US',
        'facebook',
        null,
        attribmap
    );
    System.debug('sampleData:' + sampleData);
        //test.startTest();
            verifyTestUser();
        //test.stopTest();
        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {

            User u = handler.createUser(null, sampleData);
            System.assertEquals('testLast', u.lastName);
            System.assertEquals('testFirst', u.firstName);
            List<Auth.UserData> users = new List<Auth.UserData>();
            List<Id> ids = new List<Id>(); 
            ids.add(u.Id);
            users.add(sampleData);
            handler.updateUser(u.Id, null, sampleData);
            String uid = u.id;
            List<User> processUserList = [SELECT Id, Name, FirstName, LastName, User_Provisioning_Role__c FROM USER WHERE Id =: u.id Limit 1];
            // Test Permission callout
             try {
                String requestEndpoint = KeycloakCommonService.getEndpointURL(KeycloakConstants.SERVICE_NAME_GATEWAY_SERVICE);
                
                List<UserRegistrationCommunityUser.UserVariables> processInput = new List<UserRegistrationCommunityUser.UserVariables>();
                UserRegistrationCommunityUser.UserVariables userInput = new UserRegistrationCommunityUser.UserVariables();

                userInput.userIdentifiers = processUserList;
                processInput.add(userInput);
                System.debug('processInput.size: ' + processInput.size());
                UserRegistrationCommunityUser.fetchURL(processInput);

                Test.startTest();
                // When
                // Call the getUserHdId method to get the current user's HDID
                String userHdId = UserRegistrationPermission.getUserHdId(uid);
                String requestPlaceHolder = KeycloakCommonService.replacePlaceholder(requestEndpoint, KeycloakConstants.HDID_PLACEHOLDER, userHdId);
                Test.stopTest();
        
                // Then
                // Verify the userHdId returned by the method is the same as the one stored in the Account record.
                System.assertEquals('newPersonAccount5', userHdId);                
                
            } catch (Exception e) {
                System.debug('applyPermissions: ' + e.getMessage());
            } 
            
        }
  
  }
  @isTest
  public static void testUpdateBetaUser() {
  String uniqueUserName =
      'standarduser' +
      DateTime.now().getTime() +
      '@testorg.com';

  List<UserRole> userRole = [SELECT Id FROM UserRole];
  String userRoleId = userRole[0].Id;
  KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();

  Map<String,String> attribmap = new Map<String,String>();
  attribmap.put('roles', 'BCSC_TESTONLY');
  attribmap.put('pidp_email', 'moa11@phsa.ca');
  attribmap.put('given_name', 'testFirst');
  attribmap.put('family_name', 'testLast');
  attribmap.put('email', 'TESTONLYBCSC5@EMAIL.com');
  attribmap.put('personemail', 'TESTONLYBCSC5@EMAIL.com');
  attribmap.put('preferred_username', 'pidp.eleven9@bcproviderstaging.onmicrosoft.com@bcp');
  attribmap.put('name', 'testFirst testLast');
  attribmap.put('hdid', 'newPersonAccount5');
  attribmap.put('idp', 'BCSC_TESTONLY');

  Auth.UserData sampleData = new Auth.UserData(
      'testId',
      'testFirst',
      'testLast',
      'testFirst testLast',
      'testuser@example.org',
      null,
      'testuserlong',
      'en_US',
      'facebook',
      null,
      attribmap
  );
  System.debug('sampleData:' + sampleData);
      //test.startTest();
          verifyTestUser();
      //test.stopTest();
      User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
      System.runAs(runtimeUser) {

          User u = handler.createUser(null, sampleData);
          System.assertEquals('testLast', u.lastName);
          System.assertEquals('testFirst', u.firstName);
          List<Auth.UserData> users = new List<Auth.UserData>();
          List<Id> ids = new List<Id>(); 
          ids.add(u.Id);
          users.add(sampleData);
          handler.updateUser(u.Id, null, sampleData);
          String uid = u.id;
          List<User> processUserList = [SELECT Id, Name, FirstName, LastName, User_Provisioning_Role__c FROM USER WHERE Id =: u.id Limit 1];
          // Test Permission callout
           try {
              String requestEndpoint = KeycloakCommonService.getEndpointURL(KeycloakConstants.SERVICE_NAME_GATEWAY_SERVICE);
              
              List<UserRegistrationBetaUser.UserVariables> processInput = new List<UserRegistrationBetaUser.UserVariables>();
              UserRegistrationBetaUser.UserVariables userInput = new UserRegistrationBetaUser.UserVariables();

              userInput.userIdentifiers = processUserList;
              processInput.add(userInput);
              System.debug('processInput.size: ' + processInput.size());
              UserRegistrationBetaUser.applyBetaUsers(processInput);

              Test.startTest();
              // When
              // Call the getUserHdId method to get the current user's HDID
              String userHdId = UserRegistrationPermission.getUserHdId(uid);
              String requestPlaceHolder = KeycloakCommonService.replacePlaceholder(requestEndpoint, KeycloakConstants.HDID_PLACEHOLDER, userHdId);
              Test.stopTest();
      
              // Then
              // Verify the userHdId returned by the method is the same as the one stored in the Account record.
              System.assertEquals('newPersonAccount5', userHdId);                
              
          } catch (Exception e) {
              System.debug('applyPermissions: ' + e.getMessage());
          } 
          
      }

}

  @isTest
    public static void testUpdateCommunityNewAccountUser() {
    String uniqueUserName =
        'standarduser' +
        DateTime.now().getTime() +
        '@testorg.com';

    List<UserRole> userRole = [SELECT Id FROM UserRole];
    String userRoleId = userRole[0].Id;
    KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();

    Map<String,String> attribmap = new Map<String,String>();
    attribmap.put('roles', 'BCSC_TESTONLY');
    attribmap.put('pidp_email', 'moa12@phsa.ca');
    attribmap.put('given_name', 'testFirstacct');
    attribmap.put('family_name', 'testLastacct');
    attribmap.put('email', 'pidp.twelve9@bcprovinderstaging.onmicrosoft.com');
    attribmap.put('preferred_username', 'pidp.twelve9@bcproviderstaging.onmicrosoft.com@bcp');
    attribmap.put('name', 'testFirstacct testLastacct');

    Auth.UserData sampleData = new Auth.UserData(
        'testIdacct',
        'testFirstacct',
        'testLastacct',
        'testFirstacct testLastacct',
        'testuseracct@example.org',
        null,
        'testuserlongacct',
        'en_US',
        'IDP_USER',
        null,
        attribmap
    );
    System.debug('sampleData:' + sampleData);
        test.startTest();
            verifyTestUser();
        test.stopTest();
        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {

            User u = handler.createUser(null, sampleData);
            System.assertEquals('testLastacct', u.lastName);
            System.assertEquals('testFirstacct', u.firstName);
            List<Auth.UserData> users = new List<Auth.UserData>();
            List<Id> ids = new List<Id>(); 
            ids.add(u.Id);
            users.add(sampleData);
            handler.updateUser(u.Id, null, sampleData);
            String uid = u.id;
        }
  
  }

  @isTest
  public static void testCreateIdirUser() {
        String uniqueUserName =
            'standarduser' +
        DateTime.now().getTime() +
            '@testorg.com';

        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
        attribmap.put('email', 'test.last@gov.bc.ca');
        attribmap.put('family_name', 'TestLast');
        attribmap.put('given_name', 'TestFirst');
        attribmap.put('preferred_username', 'test@idir');
        attribmap.put('name', 'TestFirst TestLast');
        attribmap.put('email_verified', 'false');
        attribmap.put('sub', 'f6aac22a-03bd-4d08-a9de-1a050b0e2c15');

        Auth.UserData sampleData = new Auth.UserData(
            'f6aac22a-03bd-4d08-a9de-1a050b0e2c15',
            'TestFirst',
            'TestLast',
            'TestFirst TestLast',
            'test.last@gov.bc.ca',
            null,
            'test@idir',
            'en_CA',
            'Open ID Connect',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {

            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestLast', u.lastName);
            System.assertEquals('TestFirst', u.firstName);
        }
  }

  @isTest
    public static void testCreatCPNUser() {
        String uniqueUserName =
            'standarduser' +
        DateTime.now().getTime() +
            '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();

        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'BCSC_TESTONLY');
        attribmap.put('pidp_email', 'testonly@bcsc.ca');
        attribmap.put('family_name', 'TestOnlyLast');
        attribmap.put('given_name', 'TestOnlyGiven');
        attribmap.put('common_provider_number', 'GUID01');
        attribmap.put('preferred_username', 'pidp.fifteen@bcprovidertest.onmicrosoft.com@bcp');
        attribmap.put('name', 'TestOnlyGiven TestOnlyLast');

        Auth.UserData sampleData = new Auth.UserData(
            'testIdComm',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuserComm@example.org',
            null,
            'testonly@bcsc.ca',
            'en_US',
            'Open ID Connect',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {        
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);
        }

  }

  @isTest
    public static void testCreateBCSCUser() {
        String uniqueUserName =
            'standarduser' +
            DateTime.now().getTime() +
            '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'BCSC_TESTONLY');
        attribmap.put('pidp_email', 'testonly@bcsc.ca');
        attribmap.put('family_name', 'TestOnlyLast');
        attribmap.put('given_name', 'TestOnlyGiven');
        attribmap.put('hdid','newPersonAccount4');
        attribmap.put('idp','BCSC_TESTONLY');

        Auth.UserData sampleData = new Auth.UserData(
            'testIdComm',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuserComm@example.org',
            null,
            'testusername@me.com',
            'en_US',
            'facebook',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);
        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);
        }

  }

  @isTest
    public static void testCreateProviderUser() {
        String uniqueUserName =
            'standarduser' +
        DateTime.now().getTime() +
            '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
      
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'BCSC_TESTONLY');
        attribmap.put('pidp_email', 'TESTONLYBCSC4@EMAIL.com');
        attribmap.put('family_name', 'TestOnlyLast');
        attribmap.put('given_name', 'TestOnlyGiven');
        attribmap.put('bcsc_guid','newPersonAccount4');
        attribmap.put('idp','BCSC_TESTONLY');

        Auth.UserData sampleData = new Auth.UserData(
            'testIdComm',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'TESTONLYBCSC4@EMAIL.com',
            null,
            'TESTONLYBCSC4@EMAIL.com',
            'en_US',
            'facebook',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);
        }
  }

  @isTest
    public static void testCreateMOAEndorsereUser() {
        String uniqueUserName = 
            'standarduser' +
            DateTime.now().getTime() +
            '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
      
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'BCSC_TESTONLY');
        attribmap.put('pidp_email', 'testusername3@me.com');
        attribmap.put('family_name', 'TestOnlyLast');
        attribmap.put('given_name', 'TestOnlyGiven');
        attribmap.put('endorser_data','CPN.TSTP00016.CPSID.GS');
        attribmap.put('common_provider_number', '');
        attribmap.put('preferred_username', 'pidp.fifteen@bcprovidertest.onmicrosoft.com@bcp');
        attribmap.put('name', 'TestOnlyGiven TestOnlyLast');

        Auth.UserData sampleData = new Auth.UserData(
            'testIdComm',
            'testFirst',
            'testLast',
            'testFirst testLast',
            null,
            '',
            'testusername3@me.com',
            'en_US',
            'Open ID Connect',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);
        }

  }

  @isTest
  public static void testCreateMOAEndorsereUser_emptyEndorser() {
      String uniqueUserName = 
          'standarduser' +
          DateTime.now().getTime() +
          '@testorg.com';
      Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
      List<UserRole> userRole = [SELECT Id FROM UserRole];
      String userRoleId = userRole[0].Id;
      KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
    
      Map<String,String> attribmap = new Map<String,String>();
      attribmap.put('roles', 'BCSC_TESTONLY');
      attribmap.put('pidp_email', 'testusername3@me.com');
      attribmap.put('family_name', 'TestOnlyLast');
      attribmap.put('given_name', 'TestOnlyGiven');
      attribmap.put('endorser_data','[]');
      attribmap.put('common_provider_number', '');
      attribmap.put('preferred_username', 'pidp.fifteen@bcprovidertest.onmicrosoft.com@bcp');
      attribmap.put('name', 'TestOnlyGiven TestOnlyLast');

      Auth.UserData sampleData = new Auth.UserData(
          'testIdComm',
          'testFirst',
          'testLast',
          'testFirst testLast',
          'testusername3@me.com',
          null,
          'testusername3@me.com',
          'en_US',
          'Open ID Connect',
          null,
          attribmap
      );
      System.debug('sampleData:' + sampleData);

      test.startTest();
          verifyTestUser();
      test.stopTest();

      User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
      System.runAs(runtimeUser) {
        try {
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);

        } catch (Auth.AuthProviderPluginException ae) {
            System.assertEquals('No Match found for Endorser Supplied Data', ae.getMessage());
        } catch (Exception e) {
            System.debug('Error Thrown: ' + e.getMessage());
        }

      }

}


    @isTest
    static void testCanCreateUser() {
    
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
        
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            null,
            null,
            null,
            'en_US',
            'facebook',
            null,
            attribmap
        );
        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            Boolean canCreate = handler.canCreateUser(sampleData);
            System.assert(!canCreate);
        }
    }

    @isTest
    public static void testCreateMoaNoEndorserUser() {
        String uniqueUserName = 
            'standarduser' +
            DateTime.now().getTime() +
            '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        List<UserRole> userRole = [SELECT Id FROM UserRole];
        String userRoleId = userRole[0].Id;
        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
      
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'BCSC_TESTONLY');
        //attribmap.put('pidp_email', 'testusername3@me.com');
        attribmap.put('family_name', 'TestOnlyLast');
        attribmap.put('given_name', 'TestOnlyGiven');
        attribmap.put('endorser_data','[]');
        attribmap.put('preferred_username', 'pidp.fifteen@bcprovidertest.onmicrosoft.com@bcp');
        attribmap.put('name', 'TestOnlyGiven TestOnlyLast');

        Auth.UserData sampleData = new Auth.UserData(
            'testIdComm',
            'testFirst',
            'testLast',
            'testFirst testLast',
            null,
            null,
            'testusername3@me.com',
            'en_US',
            'Open ID Connect',
            null,
            attribmap
        );
        System.debug('sampleData:' + sampleData);

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            User u = handler.createUser(null, sampleData);
            System.assertEquals('TestOnlyLast', u.lastName);
            System.assertEquals('TestOnlyGiven', u.firstName);
        }

  }

    @isTest
    static void testCreateUserExcep() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
    
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            null,
            'testuserlong',
            'en_US',
            'facebook',
            null,
            null
        );

        KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
        Boolean exceptionThrown = false;

        try {
            test.startTest();
                verifyTestUser();
            test.stopTest();

            User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
            System.runAs(runtimeUser) {
                handler.createUser(null, sampleData);
            }
        } catch(Exception e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown);
    }
    
    @isTest
    static void testDoNotCreateUser() {
        Boolean exceptionThrown = false;
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'FAIL');

    
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            'Someone',
            'Someoneelse',
            'en_US',
            'facebook',
            null,
            attribmap
        );

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            try {
                User user = handler.createUser(null, sampleData);
            } catch(Exception e) {
                exceptionThrown = true;
            }
            
            System.assert(exceptionThrown);
        }
    }
    
    @isTest
    static void testCreateUserExistingUser() {
        User currentUser = [Select Id, LastName, FirstName From User Where Id = :UserInfo.getUserId()];
        String testID = 'TEST_IDENTIFIER_1';
        update currentUser;
        
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');

        Auth.UserData sampleData = new Auth.UserData(
            testID,
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            'Someone',
            'Someoneelse',
            'en_US',
            'facebook',
            null,
            attribmap
        );

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {        
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            User user = handler.createUser(null, sampleData);
            
            System.assert(user.Id != null);
        }
    }
    
    @isTest
    static void testUpdateUser() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
    
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            'Someone',
            'Someoneelse',
            'en_US',
            'facebook',
            null,
            attribmap
        );

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            handler.updateUser(UserInfo.getUserId(), null, sampleData);
            
            User user = [Select Id, LastName, FirstName From User Where Id = :UserInfo.getUserId()];
            System.assert(user.LastName == sampleData.lastName);
            System.assert(user.FirstName == sampleData.firstName);
        }
    }
    
    @isTest
    static void testUpdateUserExcep() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
        attribmap.put('endorser_data', '[]');
        attribmap.put('pidp_email', 'testuser@example.org');
    
        Auth.UserData sampleData = new Auth.UserData(
            'testId',
            'testFirst',
            'testLast',
            'testFirst testLast',
            'testuser@example.org',
            'Someone',
            'Someoneelse',
            'en_US',
            'facebook',
            null,
            attribmap
        );

        test.startTest();
            verifyTestUser();
        test.stopTest();

        User runtimeUser = [SELECT Id FROM User WHERE Email = 'systemuser@testorg.com' LIMIT 1];
        System.runAs(runtimeUser) {
            KeycloakRegistrationHandler handler = new KeycloakRegistrationHandler();
            Boolean exceptionThrown = false;

            try {
                handler.updateUser(null, null, sampleData);
            } catch(Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }
    
    @isTest
    static void testFetchUserMappingData() {
        UserRegistrationCustomMetadataUtility processRoles = new UserRegistrationCustomMetadataUtility();
        UserRegistrationCustomMetadataUtility loadRoles = new UserRegistrationCustomMetadataUtility('SALESFORCE_TESTONLY');

        List<IDP_User_Registration_Permission_Set__mdt> fetchRoles = loadRoles.ReadPermissionSet('SALESFORCE_TESTONLY');
        system.assert(fetchRoles != null);
    }
    
    @isTest
    static void testCheckAvailableLicense() {
        
        Boolean currentLicense = UserRegistrationService.checkAvailableLicense('Salesforce');
        
        system.assert(currentLicense == true);
    }
    
    @isTest
    static void testFetchlicenseType() {
        Map<String,String> attribmap = new Map<String,String>();
        attribmap.put('roles', 'SALESFORCE_TESTONLY');
    
        Auth.UserData sampleData = new Auth.UserData(
        'testId',
        'testFirst',
        'testLast',
        'testFirst testLast',
        'testuser@example.org',
        'Someone',
        'Someoneelse',
        'en_US',
        'facebook',
        null,
        attribmap
        );

        String currentLicense = UserRegistrationService.fetchLicenseType(sampleData);
        
        system.assert(currentLicense == 'Salesforce');
    }
    @Future
    public static void verifyTestUser() {

        if (RUN_TIME_USER.Id == null) {
            UserRole userRole = new UserRole(Name='TestRoleOnly');
            Insert userRole;
            //runningUser.UserRoleId = userRole.Id;

            String uniqueUserName =
            'standarduser' +
            DateTime.now().getTime() +
            '@testorg.com';
    
            Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];

            User runningUser = new User(
                Alias = 'standt',
                Email = 'systemuser@testorg.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_CA',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = uniqueUserName,
                UserRoleId = userRole.Id
            );

            Insert runningUser;
            RUN_TIME_USER = runningUser;
        }
        
    }
}