/**
 * @description HTTP callout mock for ERP integration unit tests.
 */
@IsTest
public class ERPIntegrationMock implements HttpCalloutMock {
    private Integer statusCode;
    private String responseBody;
    private Boolean throwException;

    public ERPIntegrationMock(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
        this.throwException = false;
    }

    public ERPIntegrationMock(Boolean throwException) {
        this.throwException = throwException;
        this.statusCode = 0;
        this.responseBody = '';
    }

    public static ERPIntegrationMock successCreate() {
        return new ERPIntegrationMock(
            201,
            '{"id":"BC-ORD-001","status":"Open","externalId":"test"}'
        );
    }

    public static ERPIntegrationMock successUpdate() {
        return new ERPIntegrationMock(
            200,
            '{"id":"BC-ORD-001","status":"Released"}'
        );
    }

    public static ERPIntegrationMock serverError() {
        return new ERPIntegrationMock(500, '{"error":"Internal Server Error"}');
    }

    public static ERPIntegrationMock healthCheckSuccess() {
        return new ERPIntegrationMock(200, '{"status":"healthy"}');
    }

    public HTTPResponse respond(HTTPRequest req) {
        if (throwException) {
            throw new CalloutException('Simulated callout failure');
        }

        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(responseBody);
        res.setHeader('Content-Type', 'application/json');
        return res;
    }
}
