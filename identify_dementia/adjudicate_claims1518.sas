/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Adjudicating dementia incidence claims from Encounter data;

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

***** Formats;
proc format;
	%include "&rootpath./Projects/Programs/dementia_clms/demdx.fmt";
run;

***** Dementia Codes;
%let ccw_dx9="3310"  "33111" "33119" "3312"  "3317"  "2900"  "29010"
            "29011" "29012" "29013" "29020" "29021" "2903"  "29040" 
            "29041" "29042" "29043" "2940"  "29410" "29411" "29420" 
            "29421" "2948"  "797";
%let oth_dx9="33182" "33183" "33189" "3319" "2908" "2909" "2949" "78093" "7843" "78469";

%let ccw_dx10="F0150" "F0151" "F0280" "F0281" "F0390" "F0391" "F04" "G132" "G138" "F05"
							"F061" "F068" "G300" "G301" "G308" "G309" "G311" "G312" "G3101" "G3109"
							"G914" "G94" "R4181" "R54";

%let oth_dx10="G3183" "G3184" "G3189" "G319" "R411" "R412" "R413" "R4701" "R481" "R482" "R488" "F07" "F0789" "F079" "F09";
							
***** ICD9;
	***** Dementia Codes by type;
	%let AD_dx9="3310";
	%let ftd_dx9="33111", "33119";
	%let vasc_dx9="29040", "29041", "29042", "29043";
	%let senile_dx9="29010", "29011", "29012", "29013", "3312", "2900",  "29020", "29021", "2903", "797";
	%let unspec_dx9="29420", "29421";
	%let class_else9="3317", "2940", "29410", "29411", "2948" ;

	***** Other dementia dx codes not on the ccw list;
	%let lewy_dx9="33182";
	%let mci_dx9="33183";
	%let degen9="33189", "3319";
	%let oth_sen9="2908", "2909";
	%let oth_clelse9="2949";
	%let dem_symp9="78093", "7843", "78469","33183"; * includes MCI;

***** ICD10;
	***** Dementia Codes by type;
	%let AD_dx10="G300", "G301", "G308", "G309";
	%let ftd_dx10="G3101", "G3109";
	%let vasc_dx10="F0150", "F0151";
	%let senile_dx10="G311", "R4181", "R54";
	%let unspec_dx10="F0390", "F0391";
	%let class_else10="F0280", "F0281", "F04","F068","G138", "G94";
	* Excluded because no ICD-9 equivalent
					  G31.2 - Degeneration of nervous system due to alochol
						G91.4 - Hydrocephalus in diseases classified elsew
						F05 - Delirium due to known physiological cond
						F06.1 - Catatonic disorder due to known physiological cond
						G13.2 - Systemic atrophy aff cnsl in myxedema;
						
	***** Other dementia dx codes not on the ccw list or removed from the CCW list;
	%let lewy_dx10="G3183";
	%let mci_dx10="G3184";
	%let degen10="G3189","G319";
	%let oth_clelse10="F07","F0789","F079","F09";
	%let dem_symp10="R411","R412","R413","R4701","R481","R482","R488","G3184"; * includes MCI;
	%let ccw_excl_dx10="G312","G914","F05", "F061","G132";

* Will use a multiple step process to figure out which claims need to be adjusted.;

* Keeping all claims with claim_orig_cntl_num in main files;
* Keeping only bene_id, clm_freq_cd, clm_mdcl_rec, icd_dgns_cd:;
* Renaming to compare;
%let minyear2=15;
%let maxyear2=18;

%macro pull_orig(ctyp,maxdgns);
data &tempwork..&ctyp._clm_orig;
	set %do yr=&minyear2. %to &maxyear2.;
		enrfpl&yr..&ctyp._base_enc (where=(clm_orig_cntl_num ne "") keep=bene_id clm_orig_cntl_num clm_cntl_num clm_freq_cd clm_mdcl_rec icd_dgns_cd:)
		%end;;
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
%let max_demdx=26;
%macro getdemdx(ctyp);
	data &tempwork..&ctyp._dem_orig;
		set &tempwork..&ctyp._clm_orig;

		length odemdx1-odemdx&max_demdx $ 5;
		
		* Count how many dementia-related dx are found, separately by ccw list and other list;
		*	Keep thru_dt as dx_date;
		* Keep first 5 dx codes found;
		
		array diag [*] oicd_dgns_cd:;
		array demdx [*] odemdx1-odemdx&max_demdx;
		
		n_ccwdem=0;
		n_othdem=0;
		dxsub=0;
		
		do i=1 to dim(diag);
			if diag[i] in(&ccw_dx9,&ccw_dx10) then n_ccwdem=n_ccwdem+1; * Counting total number of CCW dementia diagnoses;
			if diag[i] in(&oth_dx9,&oth_dx10) then n_othdem=n_othdem+1; * Counting total number of other dementia diagnoses;
			* If a dementia diagnosis, checking if already accounted for, if not then creating a variable with diagnosis;
			if diag[i] in (&ccw_dx9,&ccw_dx10,&oth_dx9,&oth_dx10) then do; 
				found=0;
				do j=1 to dxsub;
					if diag[i]=demdx[j] then found=j;
				end;
				if found=0 then do;
					dxsub=dxsub+1;
					if dxsub<=&max_demdx then demdx[dxsub]=diag[i];
				end;
			end;
		end;
		
		if n_ccwdem=0 and n_othdem=0 then delete;
		
		n_demdx=sum(n_ccwdem,n_othdem);
		
		drop oicd_dgns_cd: i j n_demdx n_ccwdem n_othdem dxsub;
		
run;	
%mend getdemdx;

%getdemdx(hha);
%getdemdx(snf);
%getdemdx(op);
%getdemdx(ip);
%getdemdx(carrier);

* Do adjudication;
%macro adj(ctyp);
* Merge to the pulled dementia codes and edit;
proc sort data=&outlib..dementia_dx_&ctyp._ma15_18 out=&tempwork..&ctyp._toedit; by bene_id clm_cntl_num; run;

data &tempwork..adj_&ctyp.;
	merge &tempwork..&ctyp._toedit (in=a) &tempwork..&ctyp._dem_orig (in=b);
	by bene_id clm_cntl_num;
	toedit=a;
	edits=b;

	array demdx [*] demdx1-demdx&max_demdx.;
	array odemdx [*] odemdx1-odemdx&max_demdx.;
	array ndemdx [*] $ ndemdx1-ndemdx&max_demdx.;

	* setting up new diagnoses;
	if first.clm_cntl_num then do;
		edit="   ";
		do i=1 to &max_demdx.;
			ndemdx[i]=demdx[i];
			if demdx[i] ne "" then dxcount=i;
		end;
	end;
	retain ndemdx: edit dxcount;
	
	if toedit=1 and edits=1 then do;

		* adding diagnoses - clm_mdcl_rec ne 8 and clm_freq_cd not in(7,8);
		if oclm_freq_cd ne "" and oclm_freq_cd not in("7","8") and oclm_mdcl_rec ne "8" then do i=1 to &max_demdx.;
			add_found=0;
			if odemdx[i] ne "" then do j=1 to &max_demdx. while add_found=0;
				if odemdx[i]=ndemdx[j] then add_found=1;
			end;
			if odemdx[i] ne "" and add_found=0 then do;
				dxcount=dxcount+1;
				ndemdx[dxcount]=odemdx[i];
				substr(edit,1,1)='1';
			end;
		end;

		* replacing codes - clm_freq_cd is 7 and clm_mdcl_rec ne 8;
		if oclm_freq_cd="7" and oclm_mdcl_rec ne "8" then do i=1 to &max_demdx.;
			ndemdx[i]=odemdx[i];
			substr(edit,2,1)='7';
		end;

		* deleting diagnoses - clm_mdcl_rec="8";
		delete_found=0;
		if oclm_mdcl_rec='8' then do i=1 to &max_demdx.;
			do j=1 to &max_demdx.;
				if odemdx[i]=ndemdx[j] then do;
					delete_found=1;
					ndemdx[j]="";
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
	drop oclm_cntl_num oclm_freq_cd oclm_mdcl_rec demdx: odemdx: toedit edits i j add_found delete_found;
	rename %do i=1 %to 26; ndemdx&i.=demdx&i. %end;;	
run;

* Merge to claims that were uesd to edit and drop;
proc sort data=&tempwork..adj_&ctyp.; by bene_id oclm_cntl_num; run;

data &outlib..dementia_dx_&ctyp._adj_ma15_18 (drop=drop oclm_freq_cd oclm_mdcl_rec toedit edits) &tempwork..&ctyp._drops;
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
	else output &outlib..dementia_dx_&ctyp._adj_ma15_18;
run;

%mend;

%finalize_adj(ip);
%finalize_adj(snf);
%finalize_adj(op);
%finalize_adj(hha);
%finalize_adj(carrier);

* Checking for duplicates using their 5-key edit;
data &tempwork..hha_dup_check;
	set &outlib..dementia_dx_hha_adj_ma15_18;
	bill_type=clm_fac_type_cd||clm_srvc_clsfctn_type_cd||clm_freq_cd;
run;

proc sort data=&tempwork..hha_dup_check; by bene_id clm_from_dt clm_thru_dt org_npi bill_type; run;

data &tempwork..hha_dup_check1;
	set &tempwork..hha_dup_check;
	by bene_id clm_from_dt clm_thru_dt org_npi bill_type;
	if not(first.bill_type and last.bill_type);
run;





