import { LightningElement, wire } from 'lwc';
import getOrderSummary from '@salesforce/apex/SalesOrderService.getOrderSummary';

export default class OrderDashboard extends LightningElement {
    summary;
    isLoading = true;
    error;

    @wire(getOrderSummary)
    wiredSummary({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.summary = data;
        } else if (error) {
            this.error = error;
        }
    }
}
