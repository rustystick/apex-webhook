/**
 * @description factory class used to instantiate and or provide instances of objects used for unit testing Webhook functionality
 * @author Andi Xie
 */
@SuppressWarnings('PMD')
@isTest
public class WebhookTestFactory {
    static final String WEB_HOOK_USER_NAME = 'webhook';
    static final String OUTBOUND_WEBHOOK_PS_NAME = 'Webhook_Permissions';
    static final String INBOUND_WEBHOOK_PS_NAME = 'Inbound_Webhook_Permissions';
    public final static String TEST_BASE_URL = 'https://test.com/';
    public static List<Webhook_Registration__c> getListeners(Integer count, String eventName) {
        List<Webhook_Registration__c> listeners = new List<Webhook_Registration__c>();
        for (Integer i = 0; i < count; i++) {
            listeners.add(getListener(eventName, i == 0 ? TEST_BASE_URL : TEST_BASE_URL + i, null, null));
        }
        return listeners;
    }

    public static Webhook_Registration__c getListener(Webhook_Registration__c reg, String eventName) {
        Webhook_Registration__c newReg = reg.clone(false, false, false, false);
        newReg.Event__c = eventName;
        return newReg;
    }

    public static Webhook_Registration__c getListener(
        String eventName,
        String listenerUrl,
        String status,
        Map<String, String> headers
    ) {
        Webhook_Registration__c listener = new Webhook_Registration__c(
            Event__c = eventName,
            Callback_Url__c = listenerUrl,
            Shared_Secret__c = OutboundWebhookRegistration.generateSharedSecret(),
            Status__c = status == null ? OutboundWebhookRegistration.REGISTRATION_STATUS_ACTIVE : status,
            Header__c = headers != null ? JSON.serialize(headers) : null
        );
        return listener;
    }

    public static List<Outbound_Webhook__e> getEvents(Integer count, String eventName, List<String> eventBody) {
        List<Outbound_Webhook__e> events = new List<Outbound_Webhook__e>();
        for (Integer i = 0; i < count; i++) {
            String eventBodyString = (eventBody == null || eventBody.size() < i) ? 'test body ' + i : eventBody[i];
            events.add(getEvent(eventName, eventBodyString));
        }
        return events;
    }

    public static Outbound_Webhook__e getEvent(String eventName, String eventBody) {
        return new Outbound_Webhook__e(Event_Type__c = eventName, Event_Body__c = eventBody);
    }

    public static List<Webhook_Registration__c> getAllExistingListeners() {
        return [SELECT Id, Callback_Url__c, Header__c, Status__c, Event__c FROM Webhook_Registration__c];
    }

    public static List<Webhook_Registration__c> getAllExistingListeners(String eventName) {
        return [
            SELECT Id, Callback_Url__c, Header__c, Status__c, Event__c, Shared_Secret__c
            FROM Webhook_Registration__c
            WHERE Event__c = :eventName
        ];
    }

    public static User getSingleUser(String name, Id ProfileId) {
        String uName = name == null ? 'TestUser' : name;
        String numberString = String.valueOf(getRandomInteger(null));
        return new User(
            Alias = 'A' + numberString,
            UserName = uName + '@example.com.' + numberString,
            Email = uName + '@example.com',
            FirstName = 'Test First',
            LastName = uName,
            LOCALESIDKEY = 'en_US',
            LanguageLocaleKey = 'en_US',
            TimeZoneSidKey = 'America/Phoenix',
            ProfileId = profileId,
            EmailEncodingKey = 'UTF-8'
            );
        }
        
        public static PermissionSet getPSByName(String psName) {
            return [SELECT Id FROM PermissionSet WHERE Name = :psName LIMIT 1];
        }
        
        public static User createUserWithWebhookPS() {
            PermissionSet ps = getPSByName(OUTBOUND_WEBHOOK_PS_NAME);
            Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User'][0];
            User u = getSingleUser(WEB_HOOK_USER_NAME, profile.Id);
        insert u;
        PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = u.Id);
        insert psa;
        return u;
    }

    static Integer getRandomInteger(Integer digits) {
        Integer magnitude = digits == null ? 1000 : 10 ^ digits;
        return Math.round(Math.random() * magnitude);
    }

    public static User getWebhookUser() {
        return [SELECT Id FROM User WHERE LastName = :WEB_HOOK_USER_NAME LIMIT 1];
    }

    public static Inbound_Webhook_Setting__mdt createInboundWebhookRegistration(String path, String signatureHeaderName, String sharedSecret, String hashingAlgo){
        Map<String, Inbound_Webhook_Setting__mdt> settings = InboundWebhook.settings;
        Inbound_Webhook_Setting__mdt setting = new Inbound_Webhook_Setting__mdt(Label = path, DeveloperName =path, Signature_Header_Name__c = signatureHeaderName, Shared_Secret__c = sharedSecret, Signing_Algorithm__c = hashingAlgo );
        settings.put(path, setting);
        return setting;
    }

    public static User createUserWithInboundWebhookPS(){
        PermissionSet ps = getPSByName(INBOUND_WEBHOOK_PS_NAME);
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User'][0];
        User u = getSingleUser(WEB_HOOK_USER_NAME, profile.Id);
        insert u;
        PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = u.Id);
        insert psa;
        return u;
    }


}
