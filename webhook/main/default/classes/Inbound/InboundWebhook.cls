/**
 * @description Represents a collection of inbound webhook events and methods to operate on them
 * @author Andi Xie
 */
public with sharing class InboundWebhook {
    static final List<String> EXCLUDED_CLASS_NAMES = new List<String>{
        InboundWebhook.class.getName(),
        InboundWebhookTest.class.getName()
    };
    @TestVisible
    static Map<String, Inbound_Webhook_Setting__mdt> settings = new Map<String, Inbound_Webhook_Setting__mdt>();
    // toggled in test context to verify subsequent async processes after initial execution 
    @TestVisible
    private static Boolean startHandlerSynchronously = false;
    public static Integer eventsReceived {get; private set {
        if(eventsReceived == null) {
            eventsReceived = value;
        } else {
            eventsReceived += value;
        }
    }}
    static List<String> handlerNames;
    List<Inbound_Webhook__e> newList;
    private Map<String, List<Inbound_Webhook__e>> typeMap;

    private InboundWebhook() {
    }

    /**
     * @description set the processor to be loaded in test context.
     * Since test does not allow chaining Queues, only 1 processor name is accepted  
     * @param  handlerName processorName description
     */
    @TestVisible
    private static void setHandler(String handlerName) {
        handlerNames = new List<String>{handlerName};
        system.debug(LoggingLevel.INFO,'Setting Inbound Webhook Handler: ' + handlerName);
    }
    
    @TestVisible
    private static void setHandler(List<String> handlerNamesToSet){
        handlerNames = handlerNamesToSet;
        system.debug(LoggingLevel.INFO,'Setting Inbound Webhook Handler: ' + handlerNamesToSet);
    }

    List<String> getHandlerNames() {
        if(handlerNames != null) {
            return handlerNames;
        }
        String extendsHandler = 'extends ' + InboundWebhookEventHandler.class.getName();
        List<List<SObject>> queryResult = [FIND :extendsHandler IN ALL FIELDS RETURNING ApexClass(Name)];
        handlerNames = createNameList(queryResult[0]);
        return handlerNames;
    }

    List<String> createNameList(List<SObject> queryResult) {
        List<String> classNameList = new List<String>();
        for (ApexClass classCandidate : (List<ApexClass>) queryResult) {
            if (!EXCLUDED_CLASS_NAMES.contains(classCandidate.Name)){
                classNameList.add(classCandidate.Name);
            }
        }
        return classNameList;
    }

    /**
     * To handle additional events, create a class extend InboundWebhookEventHandler
     */

    public void startEventHandlers() {
        List<String> handlerNames = getHandlerNames();
        if (handlerNames.size() > 0) {
            String firstHandlerName = handlerNames.remove(0);
            InboundWebhookEventHandler firstHandler = (InboundWebhookEventHandler) Type.forName(firstHandlerName)
                .newInstance();
            firstHandler.setEventMapAndHandlers(typeMap, handlerNames);
            if(startHandlerSynchronously){
                firstHandler.execute();
                return;
            }
            System.enqueueJob(firstHandler);
        }
    }

    public static InboundWebhook fromNewList(List<Inbound_Webhook__e> newList) {
        InboundWebhook inboundWebhook = new InboundWebhook();
        inboundWebhook.newList = newList;
        inboundWebhook.typeMap = new Map<String, List<Inbound_Webhook__e>>();
        eventsReceived = newList.size();
        for (Inbound_Webhook__e webhook : newList) {
            String typeName = webhook.Event_Type__c;
            List<Inbound_Webhook__e> webhooks = inboundWebhook.typeMap.get(typeName);
            if (webhooks == null) {
                webhooks = new List<Inbound_Webhook__e>();
                inboundWebhook.typeMap.put(typeName, webhooks);
            }
            webhooks.add(webhook);
        }
        return inboundWebhook;
    }

    public static Inbound_Webhook_Setting__mdt getSetting(String path) {
        if (settings.get(path) == null) {
            Map<String, Inbound_Webhook_Setting__mdt> queriedSettings = Inbound_Webhook_Setting__mdt.getAll();
            for (Inbound_Webhook_Setting__mdt setting : queriedSettings.values()) {
                settings.put(setting.DeveloperName, setting);
            }
        }
        Inbound_Webhook_Setting__mdt settingToReturn = settings.get(path);
        if (settingToReturn == null) {
            throw new NoInboundWebhookSettingFoundException();
        }
        return settingToReturn;
    }

    public class NoInboundWebhookSettingFoundException extends Exception {
    }

}
