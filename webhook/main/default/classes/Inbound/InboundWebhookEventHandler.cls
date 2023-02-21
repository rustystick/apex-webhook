/**
 * @description Inbound webhook handler framework: abstract handler class containing execution and chaining logic; child class to implement handler logic
 * @author Andi Xie
 */
public abstract class InboundWebhookEventHandler implements Queueable, Database.AllowsCallouts {
    @TestVisible
    private static Boolean startHandlerSynchronously = false;
    protected List<Inbound_Webhook__e> events;
    private List<SObject> objToInsertIfError;
    private Map<String, List<Inbound_Webhook__e>> eventMap;
    private List<String> handlers;

    // main logic
    /**
     * @description Main logic to process InboundWebhook events
     */ 
    abstract void handleEvent();

    /**
     * @description provide the event name that the implementation intends to handle
     * @return   return event name
     */
    abstract String getEventTypeName();


    // for logging
    abstract String getClassName();
    virtual String getRelatedSObjectName(){
        return 'Inbound_Webhook__e';
    }

    /**
     * @description provides the event map and the remaining handler list
     * @param  eventMap events received from Inbound Webhook
     * @param  handlers list of remaining handler class names to be chained
     */ 
    public void setEventMapAndHandlers(Map<String, List<Inbound_Webhook__e>> eventMap, List<String> handlers){
        this.eventMap = eventMap;
        this.handlers = handlers;
    }

    public void execute(QueueableContext context){
        execute();
    }

    @TestVisible
    public void execute(){
        if(hasEvent()) {
            system.debug(LoggingLevel.DEBUG,'Handling inbound webhook event ' + getEventTypeName() + ' inside ' + getClassName());
            try{
                handleEvent();
            }catch(Exception ex){
                // log exception and move-on
                system.debug(LoggingLevel.ERROR,'Inbound webhook event handler ('+ getClassName() +') failed for ' + getEventTypeName() + '. Error msg: ' + ex.getMessage());
                if(objToInsertIfError != null){
                    insert objToInsertIfError;
                }
            }
        }

        if(handlers.size() == 0) return;
        // start next handler if there is any 
        String nextClassName = handlers.remove(0);
        InboundWebhookEventHandler nextProcessor = (InboundWebhookEventHandler)Type.forName(nextClassName).newInstance();
        nextProcessor.setEventMapAndHandlers(eventMap, handlers);
        if(startHandlerSynchronously){
            nextProcessor.execute();
            return;
        }
        System.enqueueJob(nextProcessor);
    }

    protected List<Inbound_Webhook__e> getEvents(){
        if(events != null) return events;
        String eventName = getEventTypeName();
        events = eventMap.get(eventName).deepClone(true, false, false);
        return events;
    }

    private Boolean hasEvent(){
        return eventMap.containsKey(getEventTypeName()); 
    }

    /**
     * @description set a item to insert in case handle event fails; usually log record
     * @param  obj record to insert
     * @return     void
     */ 
    protected void setItemToInsertIfError(SObject obj){
        if(objToInsertIfError == null){
            this.objToInsertIfError = new List<SObject>();
        }
        this.objToInsertIfError.add(obj);
    }
}
