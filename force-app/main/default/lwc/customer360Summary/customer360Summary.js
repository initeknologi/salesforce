import { LightningElement, api, wire } from 'lwc';
import getSummary from '@salesforce/apex/Customer360Controller.getSummary';

export default class Customer360Summary extends LightningElement {
    @api recordId;
    summary;
    error;

    @wire(getSummary, { accountId: '$recordId' })
    wiredSummary({ data, error }) {
        if (data) {
            this.summary = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'Unable to load customer summary.';
            this.summary = undefined;
        }
    }
}
