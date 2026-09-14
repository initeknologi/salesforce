# Managed Packages — When to Use

This repo uses native Salesforce capabilities. Managed packages are not installed here; use this as a decision reference for production programs.

| Package / area | Typical use | This demo |
|----------------|-------------|-----------|
| Salesforce CPQ | Complex quoting, bundles, renewals | Custom `Sales_Order__c` boundary object |
| NPSP / NGO | Nonprofit account model | Not applicable |
| Service Cloud add-ons | Field Service, Einstein | Standard Case + Asset only |
| Entitlements | SLA enforcement | Documented for phase 2; scratch org enables feature |
| Knowledge | Agent deflection | Not implemented; link articles to Cases in production |
| Omni-Channel | Queue routing | Assignment rules or Omni in live Service Cloud |

Install packages in a dedicated sandbox, assign licenses, and exclude package metadata from this integration repo unless the package is a hard dependency.
