/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Pulling all claim dates with dementia diagnosis, keeping diagnosis info and 
					 diagnosing physician info;
* Input: Pull dementia claims; 
* Output: dementia_dx_[ctyp]_2001_2016, dementia_carmrg_2001_2016, dementia_dxdt_2001_2016;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

/***

The next steps will be:
- Find clm_orig_cntl_num that match in original
- Merge clm_orig_cntl_num and clean those claims
- Drop old claims
- Merge in new claims
- Get on date level by clm_thru_dt - removing duplicates
- Send through my dementia incidence methods programs 
    - adjust for short time frame

Run the CCW programs on the encounter data

***/

* Will use a multiple step process to figure out which claims need to be adjusted.;

* Keeping all claims with claim_orig_cntl_num in main files;
* Keeping only bene_id, clm_freq_cd, clm_mdcl_rec, icd_dgns_cd:;
* Renaming to compare;

options obs=max;
%macro pull_orig(ctyp,maxdgns);
data &tempwork..&ctyp._clm_orig;
	set enrfpl15.&ctyp._base_enc (where=(clm_orig_cntl_num ne "") keep=bene_id clm_orig_cntl_num clm_cntl_num clm_freq_cd clm_mdcl_rec icd_dgns_cd:)
		enrfpl16.&ctyp._base_enc (where=(clm_orig_cntl_num ne "") keep=bene_id clm_orig_cntl_num clm_cntl_num clm_freq_cd clm_mdcl_rec icd_dgns_cd:)
		enrfpl17.&ctyp._base_enc (where=(clm_orig_cntl_num ne "") keep=bene_id clm_orig_cntl_num clm_cntl_num clm_freq_cd clm_mdcl_rec icd_dgns_cd:)
		enrfpl18.&ctyp._base_enc (where=(clm_orig_cntl_num ne "") keep=bene_id clm_orig_cntl_num clm_cntl_num clm_freq_cd clm_mdcl_rec icd_dgns_cd:);
	rename clm_cntl_num=oclm_cntl_num clm_orig_cntl_num=clm_cntl_num clm_freq_cd=oclm_freq_cd clm_mdcl_rec=oclm_mdcl_rec
		   %do i=1 %to &maxdgns.;
		   icd_dgns_cd&i.=oicd_dgns_cd&i.
		   %end;;
run;

proc sort data=&tempwork..&ctyp._clm_orig; by bene_id clm_cntl_num oclm_cntl_num; run;
%mend;

%pull_orig(carrier,13);
%pull_orig(hha,25);
%pull_orig(snf,25);
%pull_orig(ip,25);
%pull_orig(op,25);

* Only keeping dementia diagnoses from the original files;
%let max_arthglaudx=26;
%macro getarthglaudx(ctyp);
	data &tempwork..&ctyp._dem_orig;
		set &tempwork..&ctyp._clm_orig;

		length oarthglaudx1-oarthglaudx&max_arthglaudx $ 5;
		
		* Count how many dementia-related dx are found, separately by ccw list and other list;
		*	Keep thru_dt as dx_date;
		* Keep first 5 dx codes found;
		
		array diag [*] oicd_dgns_cd:;
		array arthglaudx [*] oarthglaudx1-oarthglaudx&max_arthglaudx;
		
		dxsub=0;
		
		do i=1 to dim(diag);
			* If a dementia diagnosis, checking if already accounted for, if not then creating a variable with diagnosis;
			if diag[i] in (&arthritis,&glaucoma) then do; 
				found=0;
				do j=1 to dxsub;
					if diag[i]=arthglaudx[j] then found=j;
				end;
				if found=0 then do;
					dxsub=dxsub+1;
					if dxsub<=&max_arthglaudx then arthglaudx[dxsub]=diag[i];
				end;
			end;
		end;
		
		if ndx=0 then delete;
		
		drop oicd_dgns_cd: i j dxsub;
		
run;	
%mend getarthglaudx;

%getarthglaudx(hha);
%getarthglaudx(snf);
%getarthglaudx(op);
%getarthglaudx(ip);
%getarthglaudx(carrier);

* Do adjudication;
%macro adj(ctyp);
* Merge to the pulled dementia codes and edit;
proc sort data=&tempwork..arthglaudx_&ctyp._15_18 out=&tempwork..&ctyp._toedit; by bene_id clm_cntl_num; run;

data &tempwork..adj_&ctyp.;
	merge &tempwork..&ctyp._toedit (in=a) &tempwork..&ctyp._dem_orig (in=b);
	by bene_id clm_cntl_num;
	toedit=a;
	edits=b;

	array arthglaudx [*] arthglaudx1-arthglaudx&max_arthglaudx.;
	array oarthglaudx [*] oarthglaudx1-oarthglaudx&max_arthglaudx.;
	array narthglaudx [*] $ narthglaudx1-narthglaudx&max_arthglaudx.;

	* setting up new diagnoses;
	if first.clm_cntl_num then do;
		edit="   ";
		do i=1 to &max_arthglaudx.;
			narthglaudx[i]=arthglaudx[i];
			if arthglaudx[i] ne "" then dxcount=i;
		end;
	end;
	retain narthglaudx: edit dxcount;
	
	if toedit=1 and edits=1 then do;

		* adding diagnoses - clm_mdcl_rec ne 8 and clm_freq_cd not in(7,8);
		add_found=0;
		if oclm_freq_cd ne "" and oclm_freq_cd not in("7","8") and oclm_mdcl_rec ne "8" then do i=1 to &max_arthglaudx.;
			do j=1 to &max_arthglaudx.;
				if oarthglaudx[i]=narthglaudx[j] then add_found=1;
			end;
			if oarthglaudx[i] ne "" and add_found=0 then do;
				dxcount=dxcount+1;
				narthglaudx[dxcount]=oarthglaudx[i];
				substr(edit,1,1)='1';
			end;
		end;

		* replacing codes - clm_freq_cd is 7 and clm_mdcl_rec ne 8;
		if oclm_freq_cd="7" and oclm_mdcl_rec ne "8" then do i=1 to &max_arthglaudx.;
			narthglaudx[i]=oarthglaudx[i];
			substr(edit,2,1)='7';
		end;

		* deleting diagnoses - clm_mdcl_rec="8";
		delete_found=0;
		if oclm_mdcl_rec='8' then do i=1 to &max_arthglaudx.;
			do j=1 to &max_arthglaudx.;
				if oarthglaudx[i]=narthglaudx[j] then do;
					delete_found=1;
					narthglaudx[j]="";
					substr(edit,3,1)='8';
				end;
			end;
		end;

		* voiding all diagnoses - clm_freq_cd = '8' and clm_mdcl_rec ne 8;
		if oclm_freq_cd='8' and oclm_mdcl_rec ne '8' then delete;

	end;

run;

proc freq data=&tempwork..adj_&ctyp.;
	table edit;
	table toedit*oclm_freq_cd;
	table toedit*edits;
run;

data &tempwork..adj_&ctyp._ck;
	set &tempwork..adj_&ctyp.;
	by bene_id clm_cntl_num;
	if not(first.clm_cntl_num and last.clm_cntl_num);
run;
%mend;

%adj(hha);
%adj(snf);
%adj(op);
%adj(ip);
%adj(carrier);

* Limit to last claim;
* Drop the diagnoses that we don't need and rename;
%macro finalize_adj(ctyp);
proc sort data=&tempwork..adj_&ctyp.; by bene_id clm_cntl_num; run;

data &tempwork..adj_&ctyp.1;
	set &tempwork..adj_&ctyp.;
	by bene_id clm_cntl_num;
	if toedit=1;
	if last.clm_cntl_num;
	drop oclm_cntl_num oclm_freq_cd oclm_mdcl_rec arthglaudx1-arthglaudx&max_arthglaudx. oarthglaudx: toedit edits i j add_found delete_found;
	rename %do i=1 %to 26; narthglaudx&i.=arthglaudx&i. %end;;	
run;

* Merge to claims that were uesd to edit and drop;
proc sort data=&tempwork..adj_&ctyp.; by bene_id oclm_cntl_num; run;

data &tempwork..arthglaudx_&ctyp._adj_ma15_18 (drop=drop oclm_freq_cd oclm_mdcl_rec toedit edits) &tempwork..&ctyp._drops;
	merge &tempwork..adj_&ctyp.1 (in=a) &tempwork..adj_&ctyp. (in=b keep=bene_id oclm_cntl_num toedit edits oclm_freq_cd oclm_mdcl_rec
	where=(edits=1) rename=(oclm_cntl_num=clm_cntl_num));
	by bene_id clm_cntl_num;
	if a;
	if b then do;
		* deleting the ones that match;
		if toedit=1 then drop=1;
		* deleting the ones that would void claims or delete diagnoses;
		if oclm_freq_cd='8' and oclm_mdcl_rec ne '8' then drop=1;
		if oclm_mdcl_rec='8' then drop=1;
	end;
	* dropping main records that have a clm_bill_freq_cd of 8 or clm_mdcl_rec of 8;
	if clm_freq_cd='8' or clm_mdcl_rec='8' then drop=1;
	if drop=1 then output &tempwork..&ctyp._drops;
	else output &tempwork..arthglaudx_&ctyp._adj_ma15_18;
run;

%mend;

%finalize_adj(ip);
%finalize_adj(snf);
%finalize_adj(op);
%finalize_adj(hha);
%finalize_adj(carrier);

* Checking for duplicates using their 5-key edit;
/*
data &tempwork..hha_dup_check;
	set &outlib..arthglau_dx_hha_adj_ma15_16;
	bill_type=clm_fac_type_cd||clm_srvc_clsfctn_type_cd||clm_freq_cd;
run;

proc sort data=&tempwork..hha_dup_check; by bene_id clm_from_dt clm_thru_dt org_npi bill_type; run;

data &tempwork..hha_dup_check1;
	set &tempwork..hha_dup_check;
	by bene_id clm_from_dt clm_thru_dt org_npi bill_type;
	if not(first.bill_type and last.bill_type);
run;
*/

%let minyear=15;
%let maxyear=18;
data &tempwork..arthglaudx_ma&minyear._&maxyear.;
		
		set &tempwork..arthglaudx_ip_adj_ma&minyear._&maxyear 
			  &tempwork..arthglaudx_op_adj_ma&minyear._&maxyear
			  &tempwork..arthglaudx_snf_adj_ma&minyear._&maxyear 
			  &tempwork..arthglaudx_hha_adj_ma&minyear._&maxyear 
			  &tempwork..arthglaudx_carrier_adj_ma&minyear._&maxyear;

		array arth [*] arthglaudx1-arthglaudx26;

		arthritis=0;
		glaucoma=0;
		do i=1 to dim(arth);
			if arth[i] in(&arthritis) then arthritis=1;
			if arth[i] in(&glaucoma) then glaucoma=1;
		end;

		ip=0;
		snf=0;
		op=0;
		hha=0;
		car=0;

		if find(clm_typ,"1") then ip=1;
		if find(clm_typ,"2") then snf=1;
		if find(clm_typ,"3") then op=1;
		if find(clm_typ,"4") then hha=1;
		if find(clm_typ,"5") then car=1;
				
run;

proc means data=&tempwork..arthglaudx_ma&minyear._&maxyear. noprint nway;
	class bene_id arthglaudx_dt;
	var ip snf op hha car;
	output out=&tempwork..arthglaudt_ma (drop=_type_ _freq_) max(ip snf op hha car)=;
run;

proc means data=&tempwork..arthglaudt_ma noprint nway;
	class bene_id;
	var arthglaudx_dt ip snf op hha car;
	output out=&tempwork..bene_arthglua_ma(drop=_type_ _freq_) min(arthglaudx_dt)=first_arthglau sum(ip snf op hha car)=;
run;





