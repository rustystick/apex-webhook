/**
 * @description Represents a single webhook registration; wrapper/utility class to perform various transactions
 * @author Andi Xie
 */
public with sharing class OutboundWebhookRegistration {
    public static final String REGISTRATION_STATUS_ACTIVE = 'Active';
    static Integer KEY_LENGTH = 256;
    Webhook_Registration__c reg;

    private OutboundWebhookRegistration(Webhook_Registration__c reg) {
        this.reg = reg;
    }

    /**
     * @description construct this with id
     * @param  id id
     * @return    return constructed object
     */ 
    public static OutboundWebhookRegistration fromId(Id id) {
        return fromIdAndFields(id, new List<String>{ 'Id' });
    }

    /**
     * @description get the sobject instance
     * @return   return the Webhook_Registration__c object 
     */
    public Webhook_Registration__c getSObject() {
        return this.reg;
    }

    /**
     * @description check if a registration already exist 
     * @param  url   url
     * @param  event event
     * @return       Id of the record if one is found
     */
    public static Id checkIfExist(String url, String event) {
        Escalade_Access ea = new Escalade_Access();
        List<Webhook_Registration__c> regs = ea.getRecordsByUrlAndEvent(url, event);
        if (regs.size() == 0) {
            throw new RegistrationNotFoundException('Does not exist');
        }
        return regs[0].Id;
    }

    /**
     * @description construct this with new Webhook_Registration with a new shared secret
     * @return   new WebhookRegistration object
     */
    public static OutboundWebhookRegistration newRegistration() {
        Webhook_Registration__c reg = new Webhook_Registration__c(Shared_Secret__c = generateSharedSecret());
        return new OutboundWebhookRegistration(reg);
    }

    /**
     * @description construct this with id and list of fields of Webhook_Registration__c SObject
     * @param  id     id of the record
     * @param  fields list of fields to query
     * @return        return constructed object
     */ 
    public static OutboundWebhookRegistration fromIdAndFields(Id id, List<String> fields) {
        String queryTemplate = 'Select {fields} FROM Webhook_Registration__c WHERE Id = :id WITH SECURITY_ENFORCED LIMIT 1';
        String query = queryTemplate.replace('{fields}', String.join(fields, ','));
        List<Webhook_Registration__c> registrations = Database.query(query);
        if (registrations.size() == 0) {
            throw new RegistrationNotFoundOrNoAccessException('No registration found with Id ' + id + ' or you do not have access');
        }
        OutboundWebhookRegistration wrapper = new OutboundWebhookRegistration(registrations[0]);
        return wrapper;
    }

    public void deleteRegistration() {
        delete reg;
    }

    /**
     * @description dynamically upsert record with a map of field values 
     * @param  fieldValues Map of field and value
     * @return             return this after upsert has been complete so it can be chained with other operations if needed
     */
    public OutboundWebhookRegistration upsertRegistration(Map<String, String> fieldValues) {
        for (String field : fieldValues.keySet()) {
            reg.put(field, fieldValues.get(field));
        }
        upsert reg;
        return this;
    }

    without sharing class Escalade_Access {
        List<Webhook_Registration__c> getRecordsByUrlAndEvent(String url, String event) {
            List<Webhook_Registration__c> registrations = [
                SELECT Id
                FROM Webhook_Registration__c
                WHERE Event__c = :event AND Callback_Url__c = :url
            ];
            return registrations;
        }
    }

    public static String generateSharedSecret() {
        Blob keyBlob = Crypto.generateAesKey(KEY_LENGTH);
        String keyString = EncodingUtil.base64Encode(keyBlob);
        return keyString;
    }

    class RegistrationNotFoundOrNoAccessException extends Exception {
    }
    public class RegistrationNotFoundException extends Exception {
    }
}
