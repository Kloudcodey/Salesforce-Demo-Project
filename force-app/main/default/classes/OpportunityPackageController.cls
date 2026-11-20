public with sharing class OpportunityPackageController {

    /*
     * Get Active Tours
     */
    @AuraEnabled(cacheable=true)
    public static List<Tour__c> getActiveTours() {

        return [
            SELECT Id,
                   Name,
                   Destinations__c,
                   Duration__c,
                   Tour_Type__c,
                   Is_Active__c,
                   Included_Services__c,
                   Excluded_Services__c
            FROM Tour__c
            WHERE Is_Active__c = true
            ORDER BY Name ASC
        ];
    }

    /*
     * Get Opportunity Packages
     */
    @AuraEnabled(cacheable=true)
    public static List<Opportunity_Package__c> getOpportunityPackages(Id opportunityId) {

        return [
            SELECT Id,
                   Name,
                   Tour__c,
                   Tour__r.Name,
                   Tour__r.Destinations__c,
                   Tour__r.Duration__c,
                   Tour__r.Tour_Type__c,
                   Tour__r.Included_Services__c,
                   Tour__r.Excluded_Services__c,
                   Opportunity__c,
                   Package_Version__c,
                   Number_of_Pax__c,
                   Pax_Category__c,
                   Single_Supplement__c,
                   Total_Package_Price__c,
                   Price_Per_Person__c,
                   Status__c,
                   Sent_Date__c,
                   Client_Response_Date__c,
                   Resend_Count__c,
                   Modification_Notes__c,
                   Custom_Itinerary__c,
                   Custom_Hotels__c,
                   Custom_Inclusions__c,
                   Custom_Exclusions__c,
                   Custom_Meals__c
            FROM Opportunity_Package__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY CreatedDate DESC
        ];
    }

    /*
     * Get Tour Costing
     */
 @AuraEnabled(cacheable=true)
public static List<Tour_Costing__c> getTourCosts(Id tourId) {

    if(tourId == null){
        return new List<Tour_Costing__c>();
    }

    return [

        SELECT Id,
               Name,
               Tour__c,
               Hotel_Tier__c,
               Duration_Days__c,
               Cost_Per_Day__c,

               Accommodation_Cost__c,
               Meals_Cost__c,
               Transport_Cost__c,
               Guide_Driver_Cost__c,
               Entry_Fees_Cost__c,
               Admin_Fee__c,
               Contribution__c,
               Senegal_Cost__c,
               Expenditure__c,
               Profit__c,
               Mark_Up__c,
               Grand_Total__c,
               Quote_to_Client__c,
               Single_Supplement__c,

               PAX_6_Total_Cost__c,
               PAX_8_Total_Cost__c,
               PAX_10_Total_Cost__c,
               PAX_12_Total_Cost__c,

               Effective_From__c,
               Effective_To__c

        FROM Tour_Costing__c
        WHERE Tour__c = :tourId
        ORDER BY CreatedDate DESC
    ];
}   /*
     * Get Tour Days
     */
    @AuraEnabled(cacheable=true)
    public static List<Tour_Day__c> getTourDays(Id tourId) {

        return [

            SELECT Id,
                   Name,
                   Day_Number__c,
                   Day_Title__c,
                   Day_Description__c,
                   Accommodation__c,
                   Meals_Included__c
            FROM Tour_Day__c
            WHERE Tour__c = :tourId
            ORDER BY Day_Number__c ASC
        ];
    }

    /*
     * Get Package Days
     */
    @AuraEnabled(cacheable=true)
    public static List<Package_Day__c> getPackageDays(Id packageId) {

        return [

            SELECT Id,
                   Name,
                   Day_Number__c,
                   Day_Title__c,
                   Day_Description__c,
                   Accommodation__c,
                   Meals_Included__c,
                   Is_Modified__c,
                   Opportunity_Package__c
            FROM Package_Day__c
            WHERE Opportunity_Package__c = :packageId
            ORDER BY Day_Number__c ASC
        ];
    }

   @AuraEnabled
public static void addPackages(

    Id opportunityId,
    List<Id> tourIds

){

    List<Opportunity_Package__c> packageList =
        new List<Opportunity_Package__c>();

    for(Id tourId : tourIds){

        Decimal pax = 10;

        Decimal totalPrice = 0;

        List<Tour_Costing__c> costingList = [

            SELECT Id,
                   PAX_6_Total_Cost__c,
                   PAX_8_Total_Cost__c,
                   PAX_10_Total_Cost__c,
                   PAX_12_Total_Cost__c
            FROM Tour_Costing__c
            WHERE Tour__c = :tourId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if(!costingList.isEmpty()){

            Tour_Costing__c cost =
                costingList[0];

            if(pax <= 6){

                totalPrice =
                    cost.PAX_6_Total_Cost__c;

            }
            else if(pax <= 8){

                totalPrice =
                    cost.PAX_8_Total_Cost__c;

            }
            else if(pax <= 10){

                totalPrice =
                    cost.PAX_10_Total_Cost__c;

            }
            else{

                totalPrice =
                    cost.PAX_12_Total_Cost__c;
            }
        }

        Opportunity_Package__c pkg =
            new Opportunity_Package__c(

                Opportunity__c = opportunityId,

                Tour__c = tourId,

                Number_of_Pax__c = pax,

                Status__c = 'Draft',

                Total_Package_Price__c = totalPrice
            );

        packageList.add(pkg);
    }

    if(!packageList.isEmpty()){

        insert packageList;
    }

    updateOpportunityAmount(opportunityId);
}
  
@AuraEnabled
public static Opportunity_Package__c updatePackage(

    Id packageId,
    Decimal numberOfPax,
    Decimal singleSupplement,
    String modificationNotes,
    String customItinerary,
    String customHotels,
    String customInclusions,
    String customExclusions,
    String customMeals

) {

    /*
     * Get Existing Package
     */
    Opportunity_Package__c existingPkg = [

        SELECT Id,
               Tour__c,
               Opportunity__c
        FROM Opportunity_Package__c
        WHERE Id = :packageId
        LIMIT 1
    ];

    /*
     * Get Tour Costing
     */
    List<Tour_Costing__c> costingList = [

        SELECT Id,
               PAX_6_Total_Cost__c,
               PAX_8_Total_Cost__c,
               PAX_10_Total_Cost__c,
               PAX_12_Total_Cost__c
        FROM Tour_Costing__c
        WHERE Tour__c = :existingPkg.Tour__c
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    Decimal totalPrice = 0;

    /*
     * Calculate Total Price
     */
    if(!costingList.isEmpty()){

        Tour_Costing__c cost = costingList[0];

        Integer pax =
            Integer.valueOf(numberOfPax);

        if(pax <= 6){

            totalPrice =
                cost.PAX_6_Total_Cost__c;

        }
        else if(pax <= 8){

            totalPrice =
                cost.PAX_8_Total_Cost__c;

        }
        else if(pax <= 10){

            totalPrice =
                cost.PAX_10_Total_Cost__c;

        }
        else{

            totalPrice =
                cost.PAX_12_Total_Cost__c;
        }
    }

    /*
     * Update Package
     */
    Opportunity_Package__c pkg =
        new Opportunity_Package__c(

            Id = packageId,

            Number_of_Pax__c = numberOfPax,

            Single_Supplement__c = singleSupplement,

            Modification_Notes__c = modificationNotes,

            Custom_Itinerary__c = customItinerary,

            Custom_Hotels__c = customHotels,

            Custom_Inclusions__c = customInclusions,

            Custom_Exclusions__c = customExclusions,

            Custom_Meals__c = customMeals,

            Total_Package_Price__c = totalPrice
        );

    update pkg;

    /*
     * Requery Updated Record
     */
    Opportunity_Package__c saved = [

        SELECT Id,
               Name,
               Tour__c,
               Tour__r.Name,
               Tour__r.Destinations__c,
               Tour__r.Duration__c,
               Tour__r.Tour_Type__c,
               Tour__r.Included_Services__c,
               Tour__r.Excluded_Services__c,
               Opportunity__c,
               Package_Version__c,
               Number_of_Pax__c,
               Pax_Category__c,
               Single_Supplement__c,
               Total_Package_Price__c,
               Price_Per_Person__c,
               Status__c,
               Sent_Date__c,
               Client_Response_Date__c,
               Resend_Count__c,
               Modification_Notes__c,
               Custom_Itinerary__c,
               Custom_Hotels__c,
               Custom_Inclusions__c,
               Custom_Exclusions__c,
               Custom_Meals__c
        FROM Opportunity_Package__c
        WHERE Id = :packageId
        LIMIT 1
    ];

    /*
     * Update Opportunity Amount
     */
    updateOpportunityAmount(
        saved.Opportunity__c
    );

    return saved;
}
    /*
     * Update Opportunity Amount
     */
    @AuraEnabled
    public static void updateOpportunityAmount(Id opportunityId) {

        if(opportunityId == null){
            return;
        }

        AggregateResult[] agg = [

            SELECT SUM(Total_Package_Price__c) totalAmt
            FROM Opportunity_Package__c
            WHERE Opportunity__c = :opportunityId
        ];

        Decimal total = 0;

        if(!agg.isEmpty() && agg[0].get('totalAmt') != null){

            total = (Decimal)agg[0].get('totalAmt');
        }

        Opportunity opp = new Opportunity(
            Id = opportunityId,
            Amount = total
        );

        update opp;
    }

    /*
     * Send Package Email
     */
    @AuraEnabled
    public static void sendPackageEmail(Id opportunityId, List<Id> packageIds) {

        Opportunity opp = [

            SELECT Id,
                   Name,
                   StageName,
                   Account.Name,
                   (
                       SELECT Contact.Email,
                              Contact.FirstName
                       FROM OpportunityContactRoles
                       WHERE IsPrimary = true
                       LIMIT 1
                   )
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        List<Opportunity_Package__c> pkgs = [

            SELECT Id,
                   Name,
                   Tour__r.Name,
                   Number_of_Pax__c,
                   Pax_Category__c,
                   Total_Package_Price__c,
                   Package_Version__c,
                   Status__c,
                   Resend_Count__c
            FROM Opportunity_Package__c
            WHERE Id IN :packageIds
        ];

        String contactEmail = null;
        String contactFirstName = 'Valued Client';

        if(!opp.OpportunityContactRoles.isEmpty()){

            contactEmail = opp.OpportunityContactRoles[0].Contact.Email;
            contactFirstName = opp.OpportunityContactRoles[0].Contact.FirstName;
        }

        String subject = 'Your Tour Package Proposal - ' + opp.Name;

        String body = 'Dear ' + contactFirstName + ',\n\n'
                    + 'Please find below your tour package details:\n\n';

        for(Opportunity_Package__c p : pkgs){

            body += 'Tour: ' + p.Tour__r.Name
                 + ' | PAX: ' + p.Number_of_Pax__c
                 + ' | Total: ' + p.Total_Package_Price__c
                 + '\n';
        }

        body += '\nRegards,\nLand Tours Team';

        if(String.isNotBlank(contactEmail)){

            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();

            mail.setToAddresses(
                new List<String>{contactEmail}
            );

            mail.setSubject(subject);
            mail.setPlainTextBody(body);
            mail.setSaveAsActivity(true);

            Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{mail}
            );
        }

        Date today = Date.today();

        for(Opportunity_Package__c p : pkgs){

            p.Status__c = 'Sent';
            p.Sent_Date__c = today;

            p.Resend_Count__c =
                (p.Resend_Count__c == null ? 0 : p.Resend_Count__c) + 1;
        }

        update pkgs;

        opp.StageName = 'Package Sent';

        update opp;
    }
}