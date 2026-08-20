import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import syncOrderToERP from '@salesforce/apex/SalesOrderService.syncOrderToERP';
import checkERPHealth from '@salesforce/apex/SalesOrderService.checkERPHealth';
import STATUS_FIELD from '@salesforce/schema/Sales_Order__c.Status__c';
import ERP_ORDER_ID_FIELD from '@salesforce/schema/Sales_Order__c.ERP_Order_Id__c';
import LAST_SYNC_FIELD from '@salesforce/schema/Sales_Order__c.Last_Sync_Date__c';
import ERROR_FIELD from '@salesforce/schema/Sales_Order__c.Sync_Error_Message__c';

const FIELDS = [STATUS_FIELD, ERP_ORDER_ID_FIELD, LAST_SYNC_FIELD, ERROR_FIELD];

export default class ErpOrderSyncPanel extends LightningElement {
    @api recordId;
    isLoading = false;
    wiredRecordResult;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord(result) {
        this.wiredRecordResult = result;
    }

    get hasRecord() {
        return !!this.wiredRecordResult?.data;
    }

    get statusLabel() {
        const value = getFieldValue(this.wiredRecordResult?.data, STATUS_FIELD);
        return value ? String(value) : '—';
    }

    get syncErrorMessage() {
        const value = getFieldValue(this.wiredRecordResult?.data, ERROR_FIELD);
        return value ? String(value) : '';
    }

    get lastSyncDate() {
        return getFieldValue(this.wiredRecordResult?.data, LAST_SYNC_FIELD);
    }

    get erpOrderId() {
        const value = getFieldValue(this.wiredRecordResult?.data, ERP_ORDER_ID_FIELD);
        return value ? String(value) : '—';
    }

    get hasError() {
        return this.statusLabel === 'Sync Failed' && this.syncErrorMessage;
    }

    get statusBadgeClass() {
        const base = 'status-badge ';
        const map = {
            Synced: 'status-synced',
            'Sync Failed': 'status-failed',
            Syncing: 'status-syncing',
            Submitted: 'status-submitted'
        };
        return base + (map[this.statusLabel] || 'status-default');
    }

    get isSyncDisabled() {
        return this.isLoading || !['Submitted', 'Sync Failed', 'Synced'].includes(this.statusLabel);
    }

    async handleSync() {
        this.isLoading = true;
        try {
            const message = await syncOrderToERP({ orderId: this.recordId });
            const isSuccess = message && message.toLowerCase().includes('successfully');
            this.showToast(
                isSuccess ? 'Success' : 'Sync Failed',
                message,
                isSuccess ? 'success' : 'error'
            );
            await refreshApex(this.wiredRecordResult);
        } catch (error) {
            const msg = error?.body?.message || error?.message || 'Sync failed';
            this.showToast('Error', msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleHealthCheck() {
        this.isLoading = true;
        try {
            const message = await checkERPHealth();
            const isHealthy = message && message.toLowerCase().includes('healthy');
            this.showToast(
                isHealthy ? 'ERP Healthy' : 'ERP Unavailable',
                message,
                isHealthy ? 'success' : 'error'
            );
        } catch (error) {
            const msg = error?.body?.message || error?.message || 'Health check failed';
            this.showToast('Error', msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
