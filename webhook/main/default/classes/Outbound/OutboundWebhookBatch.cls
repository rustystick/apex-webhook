/**
 * @description batch job to orchastrate individual webhook callout requests and fire in batches to overcome apex limit
 * @author Andi Xie
 */
public with sharing class OutboundWebhookBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    List<Outbound_Webhook__e> events;
    Map<String, List<Webhook_Registration__c>> eventNameToListenerMap;
    Map<String, Webhook_Event_Setting__mdt> eventNameToSettingMap;
    List<EventReceipientMap> outboundQueue;

    public OutboundWebhookBatch(
        List<Outbound_Webhook__e> events,
        Map<String, List<Webhook_Registration__c>> eventNameToListenerMap,
        Map<String, Webhook_Event_Setting__mdt> eventNameToSettingMap
    ) {
        this.events = events;
        this.eventNameToListenerMap = eventNameToListenerMap;
        this.eventNameToSettingMap = eventNameToSettingMap;
    }

    public List<Account> start(Database.BatchableContext bc) {
        Map<String, List<Outbound_Webhook__e>> eventTypeMap = mapType(events);
        Map<String, List<OutboundWebhookWrapper>> processedBody = processBody(eventTypeMap);
        List<EventReceipientMap> outboundQueue = prepareForAllListeners(processedBody);
        this.outboundQueue = outboundQueue;
        // HACK: returning a list of account to hold process index; since batchable only allows Iterable<Sobject> instead of the generic type Iterable<Object>
        List<Account> counter = new List<Account>();
        for (integer i = 0; i < outboundQueue.size(); i++) {
            Account a = new Account(Name = String.valueOf(i));
            counter.add(a);
        }
        return counter;
    }

    public void execute(Database.BatchableContext bc, List<Account> counter) {
        for (Account count : counter) {
            EventReceipientMap outboundMsg = outboundQueue.remove(0);
            OutboundWebhookWrapper calloutWrapper;
            try {
                calloutWrapper = outboundMsg.constructWrapper();
                calloutWrapper.post();
            } catch (CalloutException ex) {
                System.debug(LoggingLevel.ERROR, 'OutboundWebhookWrapper:post() Webhook callout error; meessage: ' + ex.getMessage() + '\n stack trace ' + ex.getStackTraceString());
                continue;
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'OutboundWebhookWrapper:post() Error; message: ' + ex.getMessage() + '\n stack trace ' + ex.getStackTraceString());
                continue;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
    }

    /**
     * @description creates a map between outbound message and receipients
     * @param  processedBody wrapped messages with processed body but without receipients
     * @return               map between outbound message and receipients to be inflated at each batch to avoid potential heap size limit
     */
    List<EventReceipientMap> prepareForAllListeners(Map<String, List<OutboundWebhookWrapper>> processedBody) {
        // List<OutboundWebhookWrapper> wrapped = new List<OutboundWebhookWrapper>();
        List<EventReceipientMap> outboundQueue = new List<EventReceipientMap>();
        for (String type : processedBody.keySet()) {
            for (OutboundWebhookWrapper msg : processedBody.get(type)) {
                List<Webhook_Registration__c> listeners = eventNameToListenerMap.get(type);
                if (listeners != null & listeners.size() > 0) {
                    for (Webhook_Registration__c listener : listeners) {
                        outboundQueue.add(new EventReceipientMap(listener, msg));
                    }
                }
            }
        }
        return outboundQueue;
    }

    /**
     * @description populate the outbound data object depending on event type
     * @param  eventTypeMap events segregated by type
     * @return              return a list of wrapped outbound webbhook with populated message
     */
    Map<String, List<OutboundWebhookWrapper>> processBody(Map<String, List<Outbound_Webhook__e>> eventTypeMap) {
        Map<String, List<OutboundWebhookWrapper>> webhookWithProcessedBody = new Map<String, List<OutboundWebhookWrapper>>();
        for (String type : eventTypeMap.keyset()) {
            List<Outbound_Webhook__e> eventsToProcess = eventTypeMap.get(type);
            List<OutboundWebhookWrapper> outboundWrapper;
            // if there is no specific body processor define via custom metadata
            if (eventNameToSettingMap.get(type) == null || eventNameToSettingMap.get(type).Body_Processor_Apex_Class_Name__c == null) {
                outboundWrapper = new List<OutboundWebhookWrapper>();
                for (Outbound_Webhook__e event : eventsToProcess) {
                    OutboundWebhookWrapper oww = new OutboundWebhookWrapper(event.Event_Body__c, type);
                    outboundWrapper.add(oww);
                }
                webhookWithProcessedBody.put(type, outboundWrapper);
                continue;
            }

            String bodyProcessorClassName = eventNameToSettingMap.get(type).Body_Processor_Apex_Class_Name__c;
            try {
                Type t = System.Type.forName(bodyProcessorClassName);
                OutboundWebhookBodyProcessor processor = (OutboundWebhookBodyProcessor) t.newInstance();
                outboundWrapper = processor.processBody(eventsToProcess);
                webhookWithProcessedBody.put(type, outboundWrapper);
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR,
                    'OutboundWebhookBodyProcessor error; class name: ' +
                    bodyProcessorClassName +
                    ' Error message: ' +
                    ex.getMessage()
                );
                continue;
            }
        }
        return webhookWithProcessedBody;
    }

    /**
     * @description segregates events by type
     * @param  events events raised
     * @return        segregated events by type
     */
    Map<String, List<Outbound_Webhook__e>> mapType(List<Outbound_Webhook__e> events) {
        Map<String, List<Outbound_Webhook__e>> eventTypeMap = new Map<String, List<Outbound_Webhook__e>>();
        for (Outbound_Webhook__e event : events) {
            String type = event.Event_Type__c;
            List<Outbound_Webhook__e> eventList = eventTypeMap.get(type);
            if (eventList == null) {
                eventList = new List<Outbound_Webhook__e>();
                eventTypeMap.put(type, eventList);
            }
            eventList.add(event);
        }
        return eventTypeMap;
    }

    class EventReceipientMap {
        Webhook_Registration__c receipient;
        OutboundWebhookWrapper outboundEvent;
        public EventReceipientMap(Webhook_Registration__c receipient, OutboundWebhookWrapper outboundEvent) {
            this.receipient = receipient;
            this.outboundEvent = outboundEvent;
        }
        /**
         * @description creates a outbound wrapper object with the specific receipient endpoint and shared secret
         * @return   return a outbound wrapper ready to fire
         */
        public OutboundWebhookWrapper constructWrapper() {
            String endPoint = receipient.Callback_Url__c;
            String key = receipient.Shared_Secret__c;
            OutboundWebhookWrapper wrapper = outboundEvent.cloneWithNewEndpoint(key, endPoint);
            if (receipient.Header__c != null) {
                Map<String, String> headers = new Map<String, String>();
                try {
                    Map<String, Object> deserailizedHeaders = (Map<String, Object>) JSON.deserializeuntyped(receipient.Header__c);
                    for (String headerKey : deserailizedHeaders.keyset()) {
                        headers.put(headerKey, (String) deserailizedHeaders.get(headerKey));
                    }
                } catch (Exception ex) {
                    // In case deserailizing custom header from record has issue for a specific listener, we'd still want the event itself to fire without the custom header
                    System.debug(LoggingLevel.ERROR, 'OutboundWebhookBatch.constructWrapper error. Error message: ' + ex.getMessage() + '\n stack trace: ' + ex.getStackTraceString());
                }
                wrapper.setCalloutHeaders(headers);
            }
            return wrapper;
        }
    }
}
