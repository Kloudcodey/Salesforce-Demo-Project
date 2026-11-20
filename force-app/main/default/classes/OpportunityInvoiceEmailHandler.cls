public class OpportunityInvoiceEmailHandler {

    @future(callout=true)
    public static void sendEmailFuture(
        List<Id> oppIds
    ){

        System.debug('===== START =====');

        try{

            // Org Wide Email
            OrgWideEmailAddress owe = [
                SELECT Id
                FROM OrgWideEmailAddress
                LIMIT 1
            ];

            // Opportunities
            List<Opportunity> oppList = [
                SELECT Id,
                       Name,
                       StageName,
                       AccountId
                FROM Opportunity
                WHERE Id IN :oppIds
            ];

            // Create Booking Vendor & Traveller
            createBookingVendorAndTraveller(
                oppList
            );
            // CREATE TASKS
            // Create Tasks
            createStageTasks(
                oppList
            );
            // Account Ids
            Set<Id> accIds = new Set<Id>();

            for(Opportunity opp : oppList){

                if(opp.AccountId != null){

                    accIds.add(
                        opp.AccountId
                    );
                }
            }

            // Contacts
            List<Contact> conList = [
                SELECT Id,
                       Name,
                       Email,
                       AccountId,
                       FirstName,
                       LastName,
                       Phone
                FROM Contact
                WHERE AccountId IN :accIds
                AND Email != NULL
            ];

            // Account -> Contact
            Map<Id, Contact> accConMap =
                new Map<Id, Contact>();

            for(Contact con : conList){

                if(
                    !accConMap.containsKey(
                        con.AccountId
                    )
                ){

                    accConMap.put(
                        con.AccountId,
                        con
                    );
                }
            }

            // Email List
            List<Messaging.SingleEmailMessage>
                emailList =
                    new List<
                        Messaging.SingleEmailMessage
                    >();

            // Loop Opportunities
            for(Opportunity opp : oppList){

                if(
                    !accConMap.containsKey(
                        opp.AccountId
                    )
                ){
                    continue;
                }

                Contact con =
                    accConMap.get(
                        opp.AccountId
                    );

                System.debug(
                    'Processing Stage : ' +
                    opp.StageName
                );

                // Attachment List
                List<Messaging.EmailFileAttachment>
                    attachments =
                        new List<
                            Messaging.EmailFileAttachment
                        >();

                String subject = '';
                String body = '';
                Id templateId;

                // ===================================
                // PACKAGE SENT
                // ===================================

                if(
                    opp.StageName ==
                    'Package Sent'
                ){

                    EmailTemplate packageTemplate = [
                        SELECT Id
                        FROM EmailTemplate
                        WHERE DeveloperName =
                        'Landtours_Tour_Package'
                        LIMIT 1
                    ];

                    templateId =
                        packageTemplate.Id;

                    Messaging.EmailFileAttachment
                        packageAtt =
                            generateAttachment(
                                'TenDayGhanaAndSengalTour',
                                opp.Id,
                                'TourPackage.pdf'
                            );

                    if(packageAtt != null){

                        attachments.add(
                            packageAtt
                        );
                    }
                }

                // ===================================
                // INVOICE SENT
                // ===================================

                else if(
                    opp.StageName ==
                    'Invoice Sent'
                ){

                    EmailTemplate invoiceTemplate = [
                        SELECT Id
                        FROM EmailTemplate
                        WHERE DeveloperName =
                        'Invoice_Email_8_Day_Ghana_Tour'
                        LIMIT 1
                    ];

                    templateId =
                        invoiceTemplate.Id;

                    Messaging.EmailFileAttachment
                        invoiceAtt =
                            generateAttachment(
                                'InvoiceFor8DayGhanaTour',
                                opp.Id,
                                'Invoice.pdf'
                            );

                    if(invoiceAtt != null){

                        attachments.add(
                            invoiceAtt
                        );
                    }
                }

                // ===================================
                // CLOSE WON
                // ===================================

                else if(
                    opp.StageName ==
                    'Closed Won'
                ){

                    subject =
                        'Tour Confirmation Documents';

                    body =
                        'Dear ' + con.Name +
                        ',<br/><br/>' +

                        'Thank you for confirming your booking.' +

                        '<br/><br/>' +

                        'Please find attached:' +

                        '<br/>• Confirmation Form' +
                        '<br/>• Visa Support Letter' +

                        '<br/><br/>Regards,<br/>Travel Team';

                    Messaging.EmailFileAttachment
                        att1 =
                            generateAttachment(
                                'confirmationForm',
                                opp.Id,
                                'ConfirmationForm.pdf'
                            );

                    if(att1 != null){

                        attachments.add(att1);
                    }

                    Messaging.EmailFileAttachment
                        att2 =
                            generateAttachment(
                                'visaSupportLetter',
                                opp.Id,
                                'VisaSupportLetter.pdf'
                            );

                    if(att2 != null){

                        attachments.add(att2);
                    }
                }

                // ===================================
                // DOCUMENTS SENT
                // ===================================

                else if(
                    opp.StageName ==
                    'Documents Sent'
                ){

                    subject =
                        'Ghana Travel Guide';

                    body =
                        'Dear ' + con.Name +
                        ',<br/><br/>' +

                        'Please find attached your Ghana Travel Guide.' +

                        '<br/><br/>Regards,<br/>Travel Team';

                    Messaging.EmailFileAttachment
                        att3 =
                            generateAttachment(
                                'ghanaTravelGuide',
                                opp.Id,
                                'GhanaTravelGuide.pdf'
                            );

                    if(att3 != null){

                        attachments.add(att3);
                    }
                }

                // ===================================
                // DEPOSIT RECEIVED
                // ===================================

                else if(
                    opp.StageName ==
                    'Deposit Received'
                ){

                    subject =
                        'Deposit Payment & Refund Policy';

                    body =
                        'Dear ' + con.Name +
                        ',<br/><br/>' +

                        'Thank you for your payment.' +

                        '<br/><br/>' +

                        'Please find attached Deposit Payment & Refund Policy.' +

                        '<br/><br/>Regards,<br/>Travel Team';

                    Messaging.EmailFileAttachment
                        att4 =
                            generateAttachment(
                                'depositPaymentandRefundPolicy',
                                opp.Id,
                                'DepositPolicy.pdf'
                            );

                    if(att4 != null){

                        attachments.add(att4);
                    }
                }

                // No Attachments
                if(attachments.isEmpty()){

                    continue;
                }

                // ===================================
                // EMAIL
                // ===================================

                Messaging.SingleEmailMessage mail =
                    new Messaging.SingleEmailMessage();

                // Org Wide Email
                mail.setOrgWideEmailAddressId(
                    owe.Id
                );

                // Contact
                mail.setTargetObjectId(
                    con.Id
                );

                mail.setTreatTargetObjectAsRecipient(
                    true
                );

                // Related Opportunity
                mail.setWhatId(
                    opp.Id
                );

                // Template OR Body
                if(templateId != null){

                    mail.setTemplateId(
                        templateId
                    );

                }else{

                    mail.setSubject(
                        subject
                    );

                    mail.setHtmlBody(
                        body
                    );
                }

                // Activity Timeline
                mail.setSaveAsActivity(
                    true
                );

                // Attachments
                mail.setFileAttachments(
                    attachments
                );

                emailList.add(mail);

                System.debug(
                    'Email Added'
                );
            }

            // ===================================
            // SEND EMAILS
            // ===================================

            if(!emailList.isEmpty()){

                Messaging.SendEmailResult[]
                    results =
                        Messaging.sendEmail(
                            emailList,
                            false
                        );

                for(
                    Messaging.SendEmailResult res :
                    results
                ){

                    System.debug(
                        'Success : ' +
                        res.isSuccess()
                    );

                    if(!res.isSuccess()){

                        for(
                            Messaging.SendEmailError err :
                            res.getErrors()
                        ){

                            System.debug(
                                'Error : ' +
                                err.getMessage()
                            );
                        }
                    }
                }
            }

        }catch(Exception e){

            System.debug(
                'Main Error : ' +
                e.getMessage()
            );
        }

        System.debug('===== END =====');
    }

    // ===================================
    // GENERATE PDF ATTACHMENT
    // ===================================

    public static Messaging.EmailFileAttachment
        generateAttachment(
            String pageName,
            Id oppId,
            String fileName
        ){

        try{

            PageReference pdfPage;

            // Invoice
            if(
                pageName ==
                'InvoiceFor8DayGhanaTour'
            ){

                pdfPage =
                    Page.InvoiceFor8DayGhanaTour;
            }

            // Package
            else if(
                pageName ==
                'TenDayGhanaAndSengalTour'
            ){

                pdfPage =
                    Page.TenDayGhanaAndSenegalTour;
            }

            // Confirmation Form
            else if(
                pageName ==
                'confirmationForm'
            ){

                pdfPage =
                    Page.confirmationForm;
            }

            // Visa Support
            else if(
                pageName ==
                'visaSupportLetter'
            ){

                pdfPage =
                    Page.visaSupportLetter;
            }

            // Travel Guide
            else if(
                pageName ==
                'ghanaTravelGuide'
            ){

                pdfPage =
                    Page.ghanaTravelGuide;
            }

            // Deposit Policy
            else if(
                pageName ==
                'depositPaymentandRefundPolicy'
            ){

                pdfPage =
                    Page.depositPaymentandRefundPolicy;
            }

            else{

                return null;
            }

            pdfPage.getParameters().put(
                'id',
                oppId
            );

            Blob pdfBody =
                pdfPage.getContentAsPDF();

            Messaging.EmailFileAttachment
                attachment =
                    new Messaging.EmailFileAttachment();

            attachment.setFileName(
                fileName
            );

            attachment.setBody(
                pdfBody
            );

            attachment.setContentType(
                'application/pdf'
            );

            return attachment;

        }catch(Exception ex){

            System.debug(
                'PDF Error : ' +
                ex.getMessage()
            );

            return null;
        }
    }

    // ===================================
    // CREATE BOOKING VENDOR & TRAVELLER
    // ===================================

    public static void createBookingVendorAndTraveller(
        List<Opportunity> oppList
    ){

        try{

            // Vendors
            List<Vendor__c> vendorList = [
                SELECT Id,
                       Name,
                       Vendor_Type__c
                FROM Vendor__c
                WHERE Is_Preferred__c = true
            ];

            // Booking Vendors
            List<Booking_Vendor__c>
                bookingVendorList =
                    new List<
                        Booking_Vendor__c
                    >();

            // Travellers
            List<Traveller__c>
                travellerList =
                    new List<
                        Traveller__c
                    >();

            // Contacts
            Set<Id> accIds =
                new Set<Id>();

            for(Opportunity opp : oppList){

                if(opp.AccountId != null){

                    accIds.add(
                        opp.AccountId
                    );
                }
            }

            List<Contact> conList = [
                SELECT Id,
                       FirstName,
                       LastName,
                       Phone,
                       AccountId
                FROM Contact
                WHERE AccountId IN :accIds
            ];

            Map<Id, Contact> accConMap =
                new Map<Id, Contact>();

            for(Contact con : conList){

                if(
                    !accConMap.containsKey(
                        con.AccountId
                    )
                ){

                    accConMap.put(
                        con.AccountId,
                        con
                    );
                }
            }

            // Loop Opportunities
            for(Opportunity opp : oppList){

                if(
                    opp.StageName !=
                    'Closed Won'
                ){
                    continue;
                }

                // Booking Vendors
                for(Vendor__c ven : vendorList){

                    Booking_Vendor__c bv =
                        new Booking_Vendor__c();

                    bv.Name =
                        opp.Name + ' - ' +
                        ven.Name;

                    bv.Opportunity__c =
                        opp.Id;

                   

                    bv.Service_Type__c =
                        ven.Vendor_Type__c;

                    bv.Payment_Status__c =
                        'Pending';

                    bv.Amount_Due__c = 0;

                    bv.Deposit_Paid__c = 0;

                  //  bv.Balance_Due__c = 0;

                    bv.Notes__c =
                        'Auto Created';

                    bookingVendorList.add(
                        bv
                    );
                }

                // Traveller
                if(
                    accConMap.containsKey(
                        opp.AccountId
                    )
                ){

                    Contact con =
                        accConMap.get(
                            opp.AccountId
                        );

                    Traveller__c tr =
                        new Traveller__c();

                    tr.Opportunity__c =
                        opp.Id;

                    tr.Contact__c =
                        con.Id;

                    tr.First_Name__c =
                        con.FirstName;

                    tr.Last_Name__c =
                        con.LastName;

                    tr.Room_Type__c =
                        'Double';

                    tr.Is_Single_Supplement__c =
                        false;

                    tr.Emergency_Contact__c =
                        con.Phone;

                    travellerList.add(
                        tr
                    );
                }
            }

            // Insert Booking Vendors
            if(
                !bookingVendorList.isEmpty()
            ){

                insert bookingVendorList;
            }

            // Insert Travellers
            if(
                !travellerList.isEmpty()
            ){

                insert travellerList;
            }

        }catch(Exception e){

            System.debug(
                'Create Record Error : ' +
                e.getMessage()
            );
        }
        
    }
   public static void createStageTasks(
    List<Opportunity> oppList
){

    System.debug(
        '===== TASK METHOD START ====='
    );

    List<Task> taskList =
        new List<Task>();

    try{

        for(Opportunity opp : oppList){

            System.debug(
                'Task Stage : ' +
                opp.StageName
            );

            // ===================================
            // PACKAGE SENT
            // ===================================

            if(
                opp.StageName ==
                'Package Sent'
            ){

                System.debug(
                    'Creating Package Tasks'
                );

                // Follow-Up 1
                Task t1 = new Task();

                t1.Subject =
                    'Follow-Up 1';

                t1.Status =
                    'Not Started';

                t1.Priority =
                    'Normal';

                t1.WhatId =
                    opp.Id;

                t1.OwnerId =
                    UserInfo.getUserId();

                t1.ActivityDate =
                    Date.today().addDays(2);

                taskList.add(t1);

                // Follow-Up 2
                Task t2 = new Task();

                t2.Subject =
                    'Follow-Up 2';

                t2.Status =
                    'Not Started';

                t2.Priority =
                    'High';

                t2.WhatId =
                    opp.Id;

                t2.OwnerId =
                    UserInfo.getUserId();

                t2.ActivityDate =
                    Date.today().addDays(3);

                taskList.add(t2);
            }

            // ===================================
            // DOCUMENTS SENT
            // ===================================

            else if(
                opp.StageName ==
                'Documents Sent'
            ){

                System.debug(
                    'Creating Document Tasks'
                );

                // Tour Ready
                Task t3 = new Task();

                t3.Subject =
                    'Tour Ready';

                t3.Status =
                    'Not Started';

                t3.Priority =
                    'High';

                t3.WhatId =
                    opp.Id;

                t3.OwnerId =
                    UserInfo.getUserId();

                t3.ActivityDate =
                    Date.today().addDays(5);

                taskList.add(t3);

                // Tour In Progress
                Task t4 = new Task();

                t4.Subject =
                    'Tour In Progress';

                t4.Status =
                    'Not Started';

                t4.Priority =
                    'High';

                t4.WhatId =
                    opp.Id;

                t4.OwnerId =
                    UserInfo.getUserId();

                t4.ActivityDate =
                    Date.today();

                taskList.add(t4);
            }
        }

        System.debug(
            'Task Count : ' +
            taskList.size()
        );

        if(!taskList.isEmpty()){

            insert taskList;

            System.debug(
                'TASKS CREATED SUCCESSFULLY'
            );
        }

    }catch(Exception e){

        System.debug(
            'TASK ERROR : ' +
            e.getMessage()
        );
    }

    System.debug(
        '===== TASK METHOD END ====='
    );
}
}