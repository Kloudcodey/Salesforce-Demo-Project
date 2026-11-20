public with sharing class PackageBuilderController {

    // ─────────────────────────────────────────────────────────────
    // WRAPPERS
    // ─────────────────────────────────────────────────────────────

    public class PackageDataWrapper {
        @AuraEnabled public Opportunity_Package__c packageRecord;
        @AuraEnabled public List<Package_Day__c> packageDays;
    }

    public class TourCostingWrapper {
        @AuraEnabled public Tour__c tour;
        @AuraEnabled public Tour_Costing__c costing;
        @AuraEnabled public Decimal recommendedPrice;
        @AuraEnabled public String paxCategory;
    }

    // ─────────────────────────────────────────────────────────────
    // 1. LOAD PACKAGE DATA
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static PackageDataWrapper getPackageData(Id opportunityId) {

        PackageDataWrapper wrapper = new PackageDataWrapper();

        List<Opportunity_Package__c> pkgs = [
            SELECT Id,
                   Status__c,
                   Package_Version__c,
                   Total_Package_Price__c,
                   Price_Per_Person__c,
                   Modification_Notes__c,
                   Sent_Date__c,
                   Resend_Count__c,
                   Pax_Category__c,
                   Single_Supplement__c,
                   Custom_Itinerary__c,
                   Custom_Hotels__c,
                   Custom_Meals__c,
                   Custom_Inclusions__c,
                   Custom_Exclusions__c,
                   Opportunity__c
            FROM Opportunity_Package__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY Package_Version__c DESC
            LIMIT 1
        ];

        if (!pkgs.isEmpty()) {

            wrapper.packageRecord = pkgs[0];

            wrapper.packageDays = [
                SELECT Id,
                       Day_Number__c,
                       Day_Title__c,
                       Day_Description__c,
                       Accommodation__c,
                       Meals_Included__c,
                       Is_Modified__c,
                       Opportunity_Package__c
                FROM Package_Day__c
                WHERE Opportunity_Package__c = :pkgs[0].Id
                ORDER BY Day_Number__c ASC
            ];
        }

        return wrapper;
    }

    // ─────────────────────────────────────────────────────────────
    // 2. LOAD MASTER TOUR DAYS
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Tour_Day__c> getMasterDays(Id tourId) {

        if (tourId == null) {
            return new List<Tour_Day__c>();
        }

        return [
            SELECT Id,
                   Day_Number__c,
                   Day_Title__c,
                   Day_Description__c,
                   Accommodation__c,
                   Meals_Included__c,
                   Tour__c
            FROM Tour_Day__c
            WHERE Tour__c = :tourId
            ORDER BY Day_Number__c ASC
        ];
    }

    // ─────────────────────────────────────────────────────────────
    // 3. LOAD TOUR COSTING
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static TourCostingWrapper getTourCosting(
        Id tourId,
        String hotelTier,
        Decimal numPax
    ) {

        TourCostingWrapper result = new TourCostingWrapper();

        if (tourId == null) {
            return result;
        }

        List<Tour__c> tours = [
            SELECT Id,
                   Name,
                   Base_Itinerary__c,
                   Destinations__c,
                   Duration__c,
                   Excluded_Services__c,
                   Included_Services__c,
                   Is_Active__c,
                   Tour_Type__c,
                   OwnerId
            FROM Tour__c
            WHERE Id = :tourId
            LIMIT 1
        ];

        if (!tours.isEmpty()) {
            result.tour = tours[0];
        }

        String paxCat;

        if (numPax <= 6) {
            paxCat = '6 PAX';
        }
        else if (numPax <= 8) {
            paxCat = '8 PAX';
        }
        else if (numPax <= 10) {
            paxCat = '10 PAX';
        }
        else {
            paxCat = '12+ PAX';
        }

        result.paxCategory = paxCat;

        List<Tour_Costing__c> costings = [

            SELECT Id,
                   Name,
                   Tour__c,
                   Hotel_Tier__c,
                   Duration_Days__c,
                   Accommodation_Cost__c,
                   Admin_Fee__c,
                   Entry_Fees_Cost__c,
                   Expenditure__c,
                   Grand_Total__c,
                   Guide_Driver_Cost__c,
                   Mark_Up__c,
                   Meals_Cost__c,
                   PAX_6_Total_Cost__c,
                   PAX_8_Total_Cost__c,
                   PAX_10_Total_Cost__c,
                   PAX_12_Total_Cost__c,
                   Profit__c,
                   Quote_to_Client__c,
                   Senegal_Cost__c,
                   Single_Supplement__c,
                   Transport_Cost__c,
                   Cost_Per_Day__c,
                   Contribution__c,
                   Effective_From__c,
                   Effective_To__c
            FROM Tour_Costing__c
            WHERE Tour__c = :tourId
            AND Hotel_Tier__c = :hotelTier
            AND Effective_From__c <= TODAY
            AND Effective_To__c >= TODAY
            ORDER BY Effective_From__c DESC
            LIMIT 1
        ];

        if (!costings.isEmpty()) {

            Tour_Costing__c c = costings[0];

            result.costing = c;

            if (numPax <= 6) {
                result.recommendedPrice = c.PAX_6_Total_Cost__c;
            }
            else if (numPax <= 8) {
                result.recommendedPrice = c.PAX_8_Total_Cost__c;
            }
            else if (numPax <= 10) {
                result.recommendedPrice = c.PAX_10_Total_Cost__c;
            }
            else {
                result.recommendedPrice = c.PAX_12_Total_Cost__c;
            }
        }

        return result;
    }

    // ─────────────────────────────────────────────────────────────
    // 4. GET ACTIVE TOURS
    // ─────────────────────────────────────────────────────────────

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

    // ─────────────────────────────────────────────────────────────
    // 5. GET TOUR COSTING OPTIONS
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Tour_Costing__c> getTourCostingOptions(Id tourId) {

        return [

            SELECT Id,
                   Name,
                   Hotel_Tier__c,
                   Duration_Days__c,
                   PAX_6_Total_Cost__c,
                   PAX_8_Total_Cost__c,
                   PAX_10_Total_Cost__c,
                   PAX_12_Total_Cost__c,
                   Single_Supplement__c,
                   Quote_to_Client__c,
                   Grand_Total__c,
                   Mark_Up__c,
                   Profit__c,
                   Effective_From__c,
                   Effective_To__c
            FROM Tour_Costing__c
            WHERE Tour__c = :tourId
            AND Effective_From__c <= TODAY
            AND Effective_To__c >= TODAY
            ORDER BY Hotel_Tier__c ASC
        ];
    }

    // ─────────────────────────────────────────────────────────────
    // 6. CREATE PACKAGE
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static Id createPackageFromTour(
        Id opportunityId,
        Id tourId,
        Decimal numPax,
        String hotelTier
    ) {

        Decimal totalPrice = 0;
        Decimal singleSupp = 0;

        List<Tour_Costing__c> costings = [

            SELECT PAX_6_Total_Cost__c,
                   PAX_8_Total_Cost__c,
                   PAX_10_Total_Cost__c,
                   PAX_12_Total_Cost__c,
                   Single_Supplement__c
            FROM Tour_Costing__c
            WHERE Tour__c = :tourId
            AND Hotel_Tier__c = :hotelTier
            AND Effective_From__c <= TODAY
            AND Effective_To__c >= TODAY
            ORDER BY Effective_From__c DESC
            LIMIT 1
        ];

        if (!costings.isEmpty()) {

            Tour_Costing__c c = costings[0];

            singleSupp = c.Single_Supplement__c;

            if (numPax <= 6) {
                totalPrice = c.PAX_6_Total_Cost__c;
            }
            else if (numPax <= 8) {
                totalPrice = c.PAX_8_Total_Cost__c;
            }
            else if (numPax <= 10) {
                totalPrice = c.PAX_10_Total_Cost__c;
            }
            else {
                totalPrice = c.PAX_12_Total_Cost__c;
            }
        }

        Opportunity_Package__c pkg = new Opportunity_Package__c();

        pkg.Opportunity__c = opportunityId;
        pkg.Package_Version__c = 1;
        pkg.Status__c = 'Draft';
        pkg.Total_Package_Price__c = totalPrice;
        pkg.Single_Supplement__c = singleSupp;

        insert pkg;

        List<Tour_Day__c> masterDays = [

            SELECT Day_Number__c,
                   Day_Title__c,
                   Day_Description__c,
                   Accommodation__c,
                   Meals_Included__c
            FROM Tour_Day__c
            WHERE Tour__c = :tourId
            ORDER BY Day_Number__c ASC
        ];

        List<Package_Day__c> packageDays = new List<Package_Day__c>();

        for (Tour_Day__c td : masterDays) {

            Package_Day__c pd = new Package_Day__c();

            pd.Opportunity_Package__c = pkg.Id;
            pd.Day_Number__c = td.Day_Number__c;
            pd.Day_Title__c = td.Day_Title__c;
            pd.Day_Description__c = td.Day_Description__c;
            pd.Accommodation__c = td.Accommodation__c;
            pd.Meals_Included__c = td.Meals_Included__c;
            pd.Is_Modified__c = false;

            packageDays.add(pd);
        }

        if (!packageDays.isEmpty()) {
            insert packageDays;
        }

        return pkg.Id;
    }

    // ─────────────────────────────────────────────────────────────
    // 7. SAVE VERSION
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void saveAndIncrementVersion(
        Id packageId,
        String daysJson,
        String modificationNotes
    ) {

        List<Package_Day__c> days =
            (List<Package_Day__c>) JSON.deserialize(
                daysJson,
                List<Package_Day__c>.class
            );

        update days;

        Opportunity_Package__c pkg = [

            SELECT Id,
                   Package_Version__c,
                   Resend_Count__c
            FROM Opportunity_Package__c
            WHERE Id = :packageId
            LIMIT 1
        ];

        if (pkg.Package_Version__c == null) {
            pkg.Package_Version__c = 1;
        }

        pkg.Package_Version__c =
            pkg.Package_Version__c + 1;

        if (pkg.Resend_Count__c == null) {
            pkg.Resend_Count__c = 0;
        }

        pkg.Resend_Count__c =
            pkg.Resend_Count__c + 1;

        pkg.Modification_Notes__c = modificationNotes;
        pkg.Status__c = 'Draft';

        update pkg;
    }

    // ─────────────────────────────────────────────────────────────
    // 8. ADD PACKAGE DAY
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static Package_Day__c addPackageDay(
        Id packageId,
        String dayData
    ) {

        Map<String, Object> data =
            (Map<String, Object>) JSON.deserializeUntyped(dayData);

        Package_Day__c newDay = new Package_Day__c();

        newDay.Opportunity_Package__c = packageId;
        newDay.Day_Number__c =
            Decimal.valueOf(String.valueOf(data.get('Day_Number__c')));
        newDay.Day_Title__c =
            String.valueOf(data.get('Day_Title__c'));
        newDay.Day_Description__c =
            String.valueOf(data.get('Day_Description__c'));
        newDay.Accommodation__c =
            String.valueOf(data.get('Accommodation__c'));
        newDay.Meals_Included__c =
            String.valueOf(data.get('Meals_Included__c'));
        newDay.Is_Modified__c = true;

        insert newDay;

        return newDay;
    }

    // ─────────────────────────────────────────────────────────────
    // 9. REMOVE PACKAGE DAY
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void removePackageDay(Id packageDayId) {

        delete [
            SELECT Id
            FROM Package_Day__c
            WHERE Id = :packageDayId
            LIMIT 1
        ];
    }

    // ─────────────────────────────────────────────────────────────
    // 10. SEND PACKAGE
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void triggerSendPackage(
        Id opportunityId,
        Id packageId
    ) {

        Opportunity opp = new Opportunity();

        opp.Id = opportunityId;
        opp.StageName = 'Package Sent';

        update opp;

        Opportunity_Package__c pkg =
            new Opportunity_Package__c();

        pkg.Id = packageId;
        pkg.Sent_Date__c = System.now();
        pkg.Status__c = 'Sent';

        update pkg;
    }

    // ─────────────────────────────────────────────────────────────
    // 11. VERSION HISTORY
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Opportunity_Package__c>
    getVersionHistory(Id opportunityId) {

        return [

            SELECT Id,
                   Package_Version__c,
                   Status__c,
                   Sent_Date__c,
                   Resend_Count__c,
                   Modification_Notes__c
            FROM Opportunity_Package__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY Package_Version__c DESC
        ];
    }
}