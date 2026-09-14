# End User Guide — ERP Integration Demo App

## Sales reps

### Customer record

Open **Account**. The Customer 360 panel shows open opportunities, sales orders, and support cases.

Ensure **BC Customer Id** is set (format `BC-CUST-1001`) before orders sync to ERP.

### Closing an opportunity

1. Set Stage to **Closed Won** and save.
2. A draft **Sales Order** is created automatically.
3. Open the sales order and click **Submit for Sync** (or use the ERP Sync panel).
4. Status moves to **Synced** when ERP accepts the order.

If sync fails, check **Integration Logs** for the error message and contact your Salesforce admin.

## Service agents

### Warranty cases

1. Create a Case with **Support Process** = Warranty.
2. Link an **Asset** when possible — triage sets higher priority.
3. On save, automation creates a diagnostic Task.
4. After review, set **RMA Status** to **Approved**.
5. When ERP accepts the return, **BC Return Order Id** is filled and status becomes **Sent to ERP**.

## Operations / admins

### Dashboards

Open these reports (or combine into a dashboard in Setup):

- Open Opportunities
- Sync Failed Sales Orders
- Open Warranty Cases

### Reconciliation

Admins can run **Order Reconciliation** batch to compare synced orders against ERP. Mismatches appear in Integration Logs.

### Data import

Use the **Data Migration** tab to load sample accounts and orders from JSON/CSV (sandbox only).
