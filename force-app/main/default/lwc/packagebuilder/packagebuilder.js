import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { createRecord, updateRecord, deleteRecord } from 'lightning/uiRecordApi';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import getActiveTours from '@salesforce/apex/OpportunityPackageController.getActiveTours';
import getOpportunityPackages from '@salesforce/apex/OpportunityPackageController.getOpportunityPackages';
import getTourCosts from '@salesforce/apex/OpportunityPackageController.getTourCosts';
import getTourDays from '@salesforce/apex/OpportunityPackageController.getTourDays';
import getPackageDays from '@salesforce/apex/OpportunityPackageController.getPackageDays';
import updatePackage from '@salesforce/apex/OpportunityPackageController.updatePackage';
import updateOpportunityAmount from '@salesforce/apex/OpportunityPackageController.updateOpportunityAmount';
import sendPackageEmail from '@salesforce/apex/OpportunityPackageController.sendPackageEmail';
import STAGE_FIELD from '@salesforce/schema/Opportunity.StageName';

const OPP_PACKAGE_OBJECT = 'Opportunity_Package__c';

/* ── PAX helpers ── */
function derivePaxCategory(pax) {
    const n = Math.max(0, parseInt(pax, 10) || 0);
    if (n <= 6)  return '1-6 PAX';
    if (n <= 8)  return '7-8 PAX';
    if (n <= 10) return '9-10 PAX';
    return '11-12 PAX';
}

/**
 * Returns cost-per-person for the given pax count.
 * Returns 0 (not null) when no cost row exists so callers
 * don't accidentally treat a valid 0 as "no data".
 */
function lookupCpp(costs, pax) {
    if (!costs || !costs.length) return 0;
    const row = costs[0];
    const n = parseInt(pax, 10) || 1;
    let total = 0;
    if      (n <= 6)  total = row.PAX_6_Total_Cost__c  || 0;
    else if (n <= 8)  total = row.PAX_8_Total_Cost__c  || 0;
    else if (n <= 10) total = row.PAX_10_Total_Cost__c || 0;
    else              total = row.PAX_12_Total_Cost__c || 0;
    return total / n;
}

/**
 * Given pax count, base total cost (WITHOUT single supplement),
 * and single supplement amount, return { total, ppp }.
 *
 * FIX: Single Supplement is added ON TOP of the base cost.
 *      It must never be included in baseTotal — baseTotal comes
 *      purely from tourCost rows (cpp * pax).
 */
function recalcPrices(pax, baseTotal, ss) {
    const n          = Math.max(1, parseInt(pax, 10) || 1);
    const base       = parseFloat(baseTotal) || 0;
    const supplement = parseFloat(ss)        || 0;
    const grandTotal = base + supplement;
    return {
        total : grandTotal,
        ppp   : grandTotal / n
    };
}

function getDataId(e) {
    const path = e.composedPath ? e.composedPath() : [];
    for (const el of path) {
        if (el.dataset && el.dataset.id) return el.dataset.id;
    }
    return (e.currentTarget && e.currentTarget.dataset && e.currentTarget.dataset.id)
        || (e.target        && e.target.dataset        && e.target.dataset.id)
        || null;
}

export default class OpportunityPackages extends LightningElement {

    @api recordId;

    /* ── wired packages ── */
    @track packages = [];
    wiredPackagesResult;

    @wire(getOpportunityPackages, { opportunityId: '$recordId' })
    wiredPackages(result) {
        this.wiredPackagesResult = result;
        if (result.data) {
            this.packages = result.data.map(p => this._decorate(p));
            // Pre-load tour costs for every package so the default card
            // always shows the correct price (not a stale server field value).
            const uniqueTourIds = [...new Set(result.data.map(p => p.Tour__c).filter(Boolean))];
            Promise.all(uniqueTourIds.map(id => this._loadTourData(id))).then(() => {
                // Re-decorate now that costs are cached
                this.packages = this.packages.map(p => this._decorate(p._raw || p));
            });
        } else if (result.error) {
            this.showToast('Error', result.error.body?.message, 'error');
        }
    }

    /* ── opportunity stage ── */
    @track currentStage = '';

    @wire(getRecord, { recordId: '$recordId', fields: [STAGE_FIELD] })
    wiredOpp({ data }) {
        if (data) this.currentStage = getFieldValue(data, STAGE_FIELD);
    }

    /* ── active tours for modal ── */
    @track allTours = [];

    @wire(getActiveTours)
    wiredTours({ data }) { if (data) this.allTours = data; }

    /* ── tour data cache ── */
    @track tourCostsMap  = {};
    @track tourDaysMap   = {};
    @track pkgDaysMap    = {};
    @track loadingTourId = null;
    @track loadingPkgId  = null;

    async _loadTourData(tourId) {
        if (!tourId) return;
        if (this.tourCostsMap[tourId] !== undefined) return;

        this.loadingTourId = tourId;
        try {
            const [costs, days] = await Promise.all([
                getTourCosts({ tourId }),
                getTourDays({ tourId })
            ]);
            this.tourCostsMap = { ...this.tourCostsMap, [tourId]: costs || [] };
            this.tourDaysMap  = { ...this.tourDaysMap,  [tourId]: days  || [] };
        } catch (err) {
            this.showToast('Error loading tour data', err.body?.message, 'error');
            this.tourCostsMap = { ...this.tourCostsMap, [tourId]: [] };
            this.tourDaysMap  = { ...this.tourDaysMap,  [tourId]: [] };
        } finally {
            this.loadingTourId = null;
        }
    }

    async _loadPackageDays(packageId) {
        if (!packageId) return;
        if (this.pkgDaysMap[packageId] !== undefined) return;

        this.loadingPkgId = packageId;
        try {
            const days = await getPackageDays({ packageId });
            this.pkgDaysMap = { ...this.pkgDaysMap, [packageId]: days || [] };
        } catch (err) {
            this.showToast('Error loading package days', err.body?.message, 'error');
            this.pkgDaysMap = { ...this.pkgDaysMap, [packageId]: [] };
        } finally {
            this.loadingPkgId = null;
        }
    }

    /* ── expand / collapse ── */
    @track expandedIds = new Set();

    async handleToggleExpand(e) {
        e.stopPropagation();
        const id = getDataId(e);
        if (!id) return;
        const pkg = this.packages.find(p => p.Id === id);
        if (!pkg) return;

        const next = new Set(this.expandedIds);
        if (next.has(id)) {
            next.delete(id);
        } else {
            next.add(id);
            await Promise.all([
                this._loadTourData(pkg.Tour__c),
                this._loadPackageDays(id)
            ]);
        }
        this.expandedIds = next;
        this.packages = this.packages.map(p => ({
            ...p,
            expanded    : next.has(p.Id),
            chevronIcon : next.has(p.Id) ? 'utility:chevrondown' : 'utility:chevronright'
        }));
    }

    /* ── edit ── */
    @track editDraft = {};

    handleEdit(e) {
        e.stopPropagation();
        const id = getDataId(e);
        if (!id) return;
        const pkg = this.packages.find(p => p.Id === id);
        if (!pkg) return;

        // Load tour costs in background; once loaded, refresh the price banner.
        this._loadTourData(pkg.Tour__c).then(() => {
            this._recalcEditDraftPrices(id);
        });

        const pax = parseInt(pkg.Number_of_Pax__c, 10) || 1;

        // ── FIX: Single Supplement must be read from the package field only.
        //    It must NEVER be derived from tour cost totals.
        const ss = parseFloat(pkg.Single_Supplement__c) || 0;

        // Seed the price banner from existing saved values first.
        // Once tour costs arrive async, _recalcEditDraftPrices will update them.
        let liveTotal = parseFloat(pkg.Total_Package_Price__c) || 0;
        let livePPP   = parseFloat(pkg.Price_Per_Person__c)    || 0;

        // If costs are already cached, compute immediately.
        const costs = this.tourCostsMap[pkg.Tour__c] || [];
        if (costs.length > 0) {
            const cpp = lookupCpp(costs, pax);
            if (cpp > 0) {
                // baseTotal = cpp * pax  (does NOT include ss)
                const baseTotal = cpp * pax;
                const r = recalcPrices(pax, baseTotal, ss);
                liveTotal = r.total;
                livePPP   = r.ppp;
            }
        }

        this.editDraft = {
            ...this.editDraft,
            [id]: {
                Number_of_Pax__c        : pax,
                Single_Supplement__c    : ss,   // ← always the raw SS value, never a cost total
                Modification_Notes__c   : pkg.Modification_Notes__c   || '',
                Custom_Itinerary__c     : pkg.Custom_Itinerary__c     || '',
                Custom_Hotels__c        : pkg.Custom_Hotels__c        || '',
                Custom_Inclusions__c    : pkg.Custom_Inclusions__c    || '',
                Custom_Exclusions__c    : pkg.Custom_Exclusions__c    || '',
                Custom_Meals__c         : pkg.Custom_Meals__c         || '',
                _liveTotal              : liveTotal,
                _livePPP                : livePPP,
                _livePaxCat             : derivePaxCategory(pax)
            }
        };

        this.packages = this.packages.map(p => ({
            ...p,
            isEditing: p.Id === id ? true : p.isEditing
        }));
    }

    /**
     * Called once tour costs arrive asynchronously after the edit panel opens.
     * Recalculates only the price banner fields (_liveTotal, _livePPP).
     * Does NOT touch Single_Supplement__c.
     */
    _recalcEditDraftPrices(id) {
        const d = this.editDraft[id];
        if (!d) return;

        const pkg = this.packages.find(p => p.Id === id);
        if (!pkg) return;

        const costs = this.tourCostsMap[pkg.Tour__c] || [];
        if (!costs.length) return;

        const pax = parseInt(d.Number_of_Pax__c, 10) || 1;
        const ss  = parseFloat(d.Single_Supplement__c) || 0;  // read SS from draft, not from costs
        const cpp = lookupCpp(costs, pax);

        if (cpp > 0) {
            const baseTotal = cpp * pax;
            const r = recalcPrices(pax, baseTotal, ss);
            this.editDraft = {
                ...this.editDraft,
                [id]: {
                    ...d,
                    _liveTotal  : r.total,
                    _livePPP    : r.ppp
                }
            };
        }
    }

    handleEditFieldChange(e) {
        const id    = getDataId(e);
        const field = e.currentTarget.dataset.field || e.target.dataset.field;
        const value = (e.target.type === 'number')
            ? (parseFloat(e.target.value) || 0)
            : e.target.value;

        const prev = this.editDraft[id] || {};
        const next = { ...prev, [field]: value };

        if (field === 'Number_of_Pax__c' || field === 'Single_Supplement__c') {
            const pkg    = this.packages.find(p => p.Id === id);
            const costs  = this.tourCostsMap[pkg?.Tour__c] || [];
            const newPax = field === 'Number_of_Pax__c'     ? value : prev.Number_of_Pax__c;
            const newSS  = field === 'Single_Supplement__c' ? value : prev.Single_Supplement__c;

            next._livePaxCat = derivePaxCategory(newPax);

            const cpp = lookupCpp(costs, newPax);
            if (cpp > 0) {
                // ── FIX: baseTotal = cpp * pax only; ss is separate
                const baseTotal = cpp * (parseInt(newPax, 10) || 1);
                const r = recalcPrices(newPax, baseTotal, newSS);
                next._liveTotal = r.total;
                next._livePPP   = r.ppp;
            }
        }

        this.editDraft = { ...this.editDraft, [id]: next };
    }

    handleCancelEdit(e) {
        e.stopPropagation();
        const id    = getDataId(e);
        const draft = { ...this.editDraft };
        delete draft[id];
        this.editDraft = draft;
        this.packages  = this.packages.map(p => ({
            ...p,
            isEditing: p.Id === id ? false : p.isEditing
        }));
    }

    @track isSaving = false;

    async handleSaveEdit(e) {
        e.stopPropagation();
        const id = getDataId(e);
        const d  = this.editDraft[id];
        if (!d) return;

        this.isSaving = true;
        try {
            const updated = await updatePackage({
                packageId         : id,
                numberOfPax       : d.Number_of_Pax__c,
                singleSupplement  : d.Single_Supplement__c,
                modificationNotes : d.Modification_Notes__c,
                customItinerary   : d.Custom_Itinerary__c,
                customHotels      : d.Custom_Hotels__c,
                customInclusions  : d.Custom_Inclusions__c,
                customExclusions  : d.Custom_Exclusions__c,
                customMeals       : d.Custom_Meals__c
            });

            const draft = { ...this.editDraft };
            delete draft[id];
            this.editDraft = draft;

            this.packages = this.packages.map(p =>
                p.Id === id ? this._decorate(updated) : p
            );

            // Invalidate package days cache so expanded view reloads
            const pkgDays = { ...this.pkgDaysMap };
            delete pkgDays[id];
            this.pkgDaysMap = pkgDays;

            await refreshApex(this.wiredPackagesResult);
            this.showToast('Saved', 'Package updated. Opportunity Amount recalculated.', 'success');
        } catch (err) {
            this.showToast('Save failed', err.body?.message || 'Unknown error', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    /* ── delete ── */
    async removePackage(e) {
        e.stopPropagation();
        const id = getDataId(e);
        if (!id) return;
        // eslint-disable-next-line no-alert
        if (!confirm('Remove this package?')) return;
        try {
            const pkg   = this.packages.find(p => p.Id === id);
            const oppId = pkg ? pkg.Opportunity__c : this.recordId;

            await deleteRecord(id);
            this.packages = this.packages.filter(p => p.Id !== id);

            try {
                await updateOpportunityAmount({ opportunityId: oppId });
            } catch (_) { /* non-critical */ }

            await refreshApex(this.wiredPackagesResult);
            this.showToast('Removed', 'Package removed. Opportunity Amount recalculated.', 'success');
        } catch (err) {
            this.showToast('Error removing package', err.body?.message, 'error');
        }
    }

    /* ── PAX quick-change on summary row ── */
    async handlePaxChange(e) {
        e.stopPropagation();
        const id  = getDataId(e);
        const pax = Math.max(1, parseInt(e.target.value, 10) || 1);
        try {
            await updateRecord({ fields: { Id: id, Number_of_Pax__c: pax } });
            await refreshApex(this.wiredPackagesResult);
        } catch (err) {
            this.showToast('Error updating PAX', err.body?.message, 'error');
        }
    }

    /* ── stop propagation helper ── */
    _stopProp(e) { e.stopPropagation(); }

    /* ── modal ── */
    @track modalOpen       = false;
    @track modalSearch     = '';
    @track modalTypeFilter = '';
    @track modalSelectedIds = [];

    openModal() {
        this.modalSearch      = '';
        this.modalTypeFilter  = '';
        this.modalSelectedIds = [];
        this.modalOpen        = true;
    }
    closeModal() { this.modalOpen = false; }

    handleModalSearch(e)     { this.modalSearch     = e.target.value;    }
    handleModalTypeFilter(e) { this.modalTypeFilter = e.detail.value;    }

    handleTourRowClick(e) {
        const id = e.currentTarget.dataset.id;
        if (this.packages.some(p => p.Tour__c === id)) return;
        this._toggleSel(id);
    }
    handleTourCheck(e) {
        e.stopPropagation();
        this._toggleSel(e.target.dataset.id);
    }
    _toggleSel(id) {
        const idx = this.modalSelectedIds.indexOf(id);
        this.modalSelectedIds = idx > -1
            ? this.modalSelectedIds.filter(x => x !== id)
            : [...this.modalSelectedIds, id];
    }

    async addSelected() {
        if (!this.modalSelectedIds.length) return;
        this.isSaving = true;
        let ok = 0;
        const errs = [];
        for (const tourId of this.modalSelectedIds) {
            const existing = this.packages.filter(p => p.Tour__c === tourId);
            try {
                await createRecord({
                    apiName : OPP_PACKAGE_OBJECT,
                    fields  : {
                        Opportunity__c    : this.recordId,
                        Tour__c           : tourId,
                        Status__c         : 'Draft',
                        Package_Version__c: existing.length + 1,
                        Number_of_Pax__c  : 10,
                        Resend_Count__c   : 0
                    }
                });
                ok++;
            } catch (err) {
                const msg = err.body?.output?.errors?.[0]?.message || err.body?.message || 'Unknown error';
                errs.push(msg.toLowerCase().includes('duplicate') ? 'One tour skipped (duplicate).' : msg);
            }
        }
        await refreshApex(this.wiredPackagesResult);
        if (ok)         this.showToast('Packages added', `${ok} package(s) created.`, 'success');
        if (errs.length) this.showToast('Some skipped', errs.join(' | '), 'warning');
        this.closeModal();
        this.isSaving = false;
    }

    /* ── send ── */
    async handleSend() {
        const drafts = this.packages.filter(p => p.Status__c === 'Draft');
        if (!drafts.length) return;
        this.isSaving = true;
        try {
            await sendPackageEmail({ opportunityId: this.recordId, packageIds: drafts.map(p => p.Id) });
            await refreshApex(this.wiredPackagesResult);
            this.showToast('Sent', `${drafts.length} package(s) sent.`, 'success');
        } catch (err) {
            this.showToast('Send failed', err.body?.message || 'Unknown error', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        const drafts = this.packages.filter(p => p.Status__c === 'Draft');
        if (!drafts.length) {
            this.showToast('Nothing to cancel', 'No draft packages.', 'warning');
            return;
        }
        this.showToast('Cancelled', `${drafts.length} draft(s) discarded.`, 'warning');
    }

    /* ── computed getters ── */
    get hasPackages()        { return this.packages.length > 0; }
    get badgeLabel()         { return String(this.packages.length); }
    get sendDisabled()       { return this.isSaving || !this.packages.some(p => p.Status__c === 'Draft'); }
    get noSelection()        { return this.modalSelectedIds.length === 0; }
    get selectedCountLabel() { return `${this.modalSelectedIds.length} selected`; }

    get typeOptions() {
        const types = [...new Set(this.allTours.map(t => t.Tour_Type__c).filter(Boolean))];
        return [{ label: 'All types', value: '' }, ...types.map(t => ({ label: t, value: t }))];
    }

    get filteredTours() {
        const q     = (this.modalSearch || '').toLowerCase();
        const tf    = this.modalTypeFilter;
        const added = this.packages.map(p => p.Tour__c);
        return this.allTours
            .filter(t => {
                const mq = !q  || t.Name.toLowerCase().includes(q) || (t.Destinations__c || '').toLowerCase().includes(q);
                const mt = !tf || t.Tour_Type__c === tf;
                return mq && mt;
            })
            .map(t => ({
                ...t,
                alreadyAdded : added.includes(t.Id),
                selected     : this.modalSelectedIds.includes(t.Id),
                rowClass     : added.includes(t.Id) ? 'row-added'
                             : this.modalSelectedIds.includes(t.Id) ? 'row-selected' : ''
            }));
    }

    get decoratedPackages() {
        return this.packages.map(p => {
            const d        = this.editDraft[p.Id];
            const costs    = this.tourCostsMap[p.Tour__c] || [];
            const tourDays = this.tourDaysMap[p.Tour__c]  || [];
            const pkgDays  = this.pkgDaysMap[p.Id]        || [];

            // Merge tour days with package-day overrides
            const pkgDayMap = {};
            pkgDays.forEach(pd => { pkgDayMap[pd.Day_Number__c] = pd; });
            const mergedDays = tourDays.map(td => pkgDayMap[td.Day_Number__c]
                ? { ...pkgDayMap[td.Day_Number__c], _isOverride: true }
                : { ...td, _isOverride: false }
            );
            pkgDays.forEach(pd => {
                if (!tourDays.some(td => td.Day_Number__c === pd.Day_Number__c)) {
                    mergedDays.push({ ...pd, _isOverride: true });
                }
            });
            mergedDays.sort((a, b) => (a.Day_Number__c || 0) - (b.Day_Number__c || 0));

            // For the "no cost warning": only warn if costs exist but cpp lookup failed
            const editPax = d ? parseInt(d.Number_of_Pax__c, 10) || 1 : null;
            const cpp     = d && costs.length ? lookupCpp(costs, editPax) : null;

            return {
                ...p,
                tourCosts      : costs,
                tourDays       : tourDays,
                pkgDays        : pkgDays,
                mergedDays     : mergedDays,
                hasTourCosts   : costs.length > 0,
                hasTourDays    : tourDays.length > 0,
                hasPkgDays     : pkgDays.length > 0,
                hasMergedDays  : mergedDays.length > 0,
                isLoadingTour  : this.loadingTourId === p.Tour__c || this.loadingPkgId === p.Id,
                editData       : d || {},
                // ── Display values: use live draft values when editing,
                //    otherwise use values already computed by _decorate()
                //    (derived from tour cost records, not stale server fields).
                displayTotal   : d ? d._liveTotal  : p.displayTotal,
                displayPPP     : d ? d._livePPP    : p.displayPPP,
                displayPaxCat  : d ? d._livePaxCat : p.displayPaxCat,
                showNoCostWarning : !!d && costs.length > 0 && cpp === 0,
                hasCostWarning    : costs.length === 0
            };
        });
    }

    /* ── internal ── */
    _decorate(p) {
        const pax  = parseInt(p.Number_of_Pax__c, 10) || 0;
        const ss   = parseFloat(p.Single_Supplement__c) || 0;

        // Compute display prices from cached tour costs when available.
        // This ensures the card always shows the correct price derived from
        // the cost table, not a potentially stale server field value.
        const costs = this.tourCostsMap?.[p.Tour__c] || [];
        let displayTotal = p.Total_Package_Price__c;
        let displayPPP   = p.Price_Per_Person__c;

        if (costs.length > 0 && pax > 0) {
            const cpp = lookupCpp(costs, pax);
            if (cpp > 0) {
                const r  = recalcPrices(pax, cpp * pax, ss);
                displayTotal = r.total;
                displayPPP   = r.ppp;
            }
        }

        return {
            ...p,
            _raw         : p,
            tourName     : p.Tour__r?.Name                  || '—',
            tourType     : p.Tour__r?.Tour_Type__c          || '—',
            tourDest     : p.Tour__r?.Destinations__c       || '—',
            tourDuration : p.Tour__r?.Duration__c           || '—',
            tourIncludes : p.Tour__r?.Included_Services__c  || '',
            tourExcludes : p.Tour__r?.Excluded_Services__c  || '',
            Pax_Category__c : derivePaxCategory(pax),
            displayTotal    : displayTotal,
            displayPPP      : displayPPP,
            displayPaxCat   : derivePaxCategory(pax),
            isSent          : p.Status__c === 'Sent',
            isDraft         : p.Status__c === 'Draft',
            expanded        : this.expandedIds?.has(p.Id) || false,
            chevronIcon     : this.expandedIds?.has(p.Id) ? 'utility:chevrondown' : 'utility:chevronright',
            isEditing       : !!this.editDraft?.[p.Id]
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}