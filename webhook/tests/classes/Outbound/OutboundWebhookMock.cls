/**
 * @description Callout mock for outbound webhook and listener registration api
 * @author Andi Xie
 */
@isTest
public class OutboundWebhookMock implements HttpCalloutMock {
    static Integer count = 0;
    static Map<String, List<SerializedStringDataBody>> urlBodyMap = new Map<String, List<SerializedStringDataBody>>();
    static Map<String, List<HttpRequest>> urlRequestMap = new Map<String, List<HttpRequest>>();
    Integer returnStatusCode;

    public OutboundWebhookMock() {
    }
    public OutboundWebhookMock(Integer returnStatusCode) {
        this.returnStatusCode = returnStatusCode;
    }

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        if (returnStatusCode != null) {
            response.setStatusCode(returnStatusCode);
            return response;
        }
        count++;
        String endPoint = request.getEndpoint();
        response.setHeader('Content-Type', 'application/json');
        SerializedStringDataBody body = (SerializedStringDataBody) JSON.deserialize(request.getBody(), SerializedStringDataBody.class);
        String signature = request.getHeader(OutboundWebhookWrapper.SIGNATURE_HEADER_KEY);
        if (urlBodyMap.get(endPoint) == null) {
            urlBodyMap.put(endpoint, new List<SerializedStringDataBody>());
            urlRequestMap.put(endpoint, new List<HttpRequest>());
        }
        urlBodyMap.get(endpoint).add(body);
        urlRequestMap.get(endpoint).add(request);
        return response;
    }

    public List<SerializedStringDataBody> getCalloutBodies(String url) {
        return urlBodyMap.get(url);
    }

    public Integer getCalloutCount() {
        return count;
    }

    public List<HttpRequest> getCalloutRequests(String url) {
        return urlRequestMap.get(url);
    }

    //because JSON deserailize requires a specific type, we can only test the base case string
    //for customized body types via body processor, it will be the implementer's responsibility to unit test signature there
    public class SerializedStringDataBody {
        public String data;
        public String event;
    }
}
