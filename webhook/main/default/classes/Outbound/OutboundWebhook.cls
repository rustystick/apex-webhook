/**
 * @description entry point to get all parameter need to start the callout batch for a (set of) Outbound_Webhook__e platform events
 * @author Andi Xie
 */
public with sharing class OutboundWebhook {
    static final Integer MAX_BATCH_SIZE = 100;
    static final String WEBHOOK_EVENT_LISTENER_STATUS_ACTIVE = OutboundWebhookRegistration.REGISTRATION_STATUS_ACTIVE;
    @TestVisible
    private static List<Outbound_Webhook__e> eventsReceived = new List<Outbound_Webhook__e>();
    Map<String, List<Webhook_Registration__c>> eventNameToListenerMap;
    Map<String, List<Outbound_Webhook__e>> eventNameMap;
    List<Outbound_Webhook__e> events;
    Map<String, Webhook_Event_Setting__mdt> eventNameToSettingMap;

    /**
     * @description Constructor to get relavent subscriber and event specific settings
     * @param  events events fired
     */
    public OutboundWebhook(List<Outbound_Webhook__e> events) {
        Set<String> eventNames = new Set<String>();
        Map<String, List<Webhook_Registration__c>> eventNameToListenerMap = new Map<String, List<Webhook_Registration__c>>();
        Map<String, List<Outbound_Webhook__e>> eventNameMap = new Map<String, List<Outbound_Webhook__e>>();
        Map<String, Webhook_Event_Setting__mdt> eventNameToSettingMap = new Map<String, Webhook_Event_Setting__mdt>();

        for (Outbound_Webhook__e event : events) {
            String type = event.Event_Type__c;
            if (eventNames.contains(type)) {
                List<Outbound_Webhook__e> eventList = eventNameMap.get(type);
                eventList.add(event);
                continue;
            }
            eventNames.add(type);
            eventNameToListenerMap.put(type, new List<Webhook_Registration__c>());
            eventNameMap.put(type, new List<Outbound_Webhook__e>{ event });
            eventsReceived.add(event);
        }

        List<Webhook_Registration__c> applicableListeners = [
            SELECT Callback_Url__c, Shared_Secret__c, Event__c, Header__c
            FROM Webhook_Registration__c
            WHERE Event__c IN :eventNames AND Status__c = :WEBHOOK_EVENT_LISTENER_STATUS_ACTIVE 
            WITH SECURITY_ENFORCED
        ];
        for (Webhook_Registration__c listener : applicableListeners) {
            List<Webhook_Registration__c> regList = eventNameToListenerMap.get(listener.Event__c);
            regList.add(listener);
        }
        this.eventNameToListenerMap = eventNameTOListenerMap;
        this.eventNameMap = eventNameMap;
        this.events = events;
        loadBodyProcessor();
    }

    private void loadBodyProcessor() {
        for (Webhook_Event_Setting__mdt setting : [
            SELECT Body_Processor_Apex_Class_Name__c, Event_Type__c
            FROM Webhook_Event_Setting__mdt
            WHERE Event_Type__c IN :eventNames
            WITH SECURITY_ENFORCED
        ]) {
            if (setting.Body_Processor_Apex_Class_Name__c == null) {
                continue;
            }
            eventNameToSettingMap.put(setting.Event_Type__c, setting);
        }

        this.eventNameToSettingMap = eventNameToSettingMap;
    }

    /**
     * @description entry method to start the callout batch job
     */
    public void startCallOutBatch() {
        OutboundWebhookBatch batch = new OutboundWebhookBatch(events, eventNameToListenerMap, eventNameToSettingMap);
        Database.executeBatch(batch, getBatchSize());
    }

    Integer getBatchSize() {
        Integer orgSettingBatchSize = Webhook_Settings__c.getOrgDefaults().Batch_Size__c == null
            ? MAX_BATCH_SIZE
            : (Integer) Webhook_Settings__c.getOrgDefaults().Batch_Size__c;
        return orgSettingBatchSize > MAX_BATCH_SIZE ? MAX_BATCH_SIZE : orgSettingBatchSize;
    }
}
