public class TourResponseController {

    public String message {get; set;}

    public Boolean showAcceptForm {get; set;}
    public Boolean showRejectForm {get; set;}

    public Integer numberOfPax {get; set;}
    public Integer numberOfPerson {get; set;}

    public String rejectReason {get; set;}

    public Opportunity opp {get; set;}

    public TourResponseController() {

        String recordId = ApexPages.currentPage().getParameters().get('id');
        String actionType = ApexPages.currentPage().getParameters().get('action');

        if(recordId != null && actionType != null) {

            List<Opportunity> oppList = [

                SELECT Id,
                       StageName,
                       Package_Accepted__c,
                       Package_Rejected__c,
                       Package_Reject_Reason__c,
                       Number_of_Pax__c,
                       Number_of_Person__c

                FROM Opportunity
                WHERE Id = :recordId
                LIMIT 1
            ];

            if(!oppList.isEmpty()) {

                opp = oppList[0];

            if(opp.StageName == 'Package Revised & Resent') {

            opp.Package_Accepted__c = false;

            opp.Package_Rejected__c = false;

            update opp;
           }

                if(actionType == 'accept') {

                    if(opp.Package_Accepted__c == true) {

                        message = 'This package has already been accepted.';
                    }

                    else if(opp.Package_Rejected__c == true) {

                        message = 'This package has already been rejected.';
                    }

                    else {

                        showAcceptForm = true;
                    }
                }

                else if(actionType == 'reject') {

                    if(opp.Package_Rejected__c == true) {

                        message = 'This package has already been rejected.';
                    }

                    else if(opp.Package_Accepted__c == true) {

                        message = 'This package has already been accepted.';
                    }

                    else {

                        showRejectForm = true;
                    }
                }
            }
        }
    }

    public PageReference saveAcceptance() {

        opp.StageName = 'Package Accepted';

        opp.Number_of_Pax__c = numberOfPax;

        opp.Number_of_Person__c = numberOfPerson;

        opp.Package_Accepted__c = true;

        update opp;

        showAcceptForm = false;

        message = 'Thank you! Your details have been submitted successfully. Our team will contact you shortly.';

        return null;
    }

    public PageReference saveRejection() {
        
        opp.StageName = 'Modification Requested';

        opp.Package_Rejected__c = true;

        opp.Package_Reject_Reason__c = rejectReason;

        update opp;

        showRejectForm = false;

        message = 'Thank you for your feedback. Our team will review your request and contact you shortly.';

        return null;
    }
}