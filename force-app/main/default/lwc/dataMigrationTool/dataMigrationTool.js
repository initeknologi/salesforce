import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import importOrders from '@salesforce/apex/DataMigrationService.importOrders';

const SAMPLE_PAYLOAD = JSON.stringify([
    {
        accountName: 'Acme Corp',
        orderDate: '2025-06-01',
        totalAmount: 1500,
        description: 'Sample ETL import',
        status: 'Draft'
    }
], null, 2);

export default class DataMigrationTool extends LightningElement {
    jsonPayload = SAMPLE_PAYLOAD;
    isLoading = false;
    result;

    get hasErrors() {
        return this.result?.errors?.length > 0;
    }

    handlePayloadChange(event) {
        this.jsonPayload = event.target.value;
    }

    async handleImport() {
        this.isLoading = true;
        this.result = null;
        try {
            this.result = await importOrders({ jsonPayload: this.jsonPayload });
            const variant = this.result.errorCount > 0 ? 'warning' : 'success';
            this.showToast(
                'Import Complete',
                `${this.result.successCount} of ${this.result.totalRecords} records imported.`,
                variant
            );
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Import failed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
