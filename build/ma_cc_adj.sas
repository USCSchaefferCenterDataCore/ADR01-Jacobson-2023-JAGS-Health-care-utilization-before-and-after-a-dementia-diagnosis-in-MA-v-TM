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
%let minyear=15;
%let maxyear=16;
%let maxdx=26;

%macro pull_orig(ctyp,maxdgns);
%do year=&minyear. %to &maxyear.;
data &tempwork..&ctyp._clm_orig&year.;
	set enrfpl&year..&ctyp._base_enc (where=(clm_orig_cntl_num ne "") keep=bene_id clm_orig_cntl_num clm_cntl_num clm_freq_cd clm_mdcl_rec icd_dgns_cd:);
		rename clm_cntl_num=oclm_cntl_num clm_orig_cntl_num=clm_cntl_num clm_freq_cd=oclm_freq_cd clm_mdcl_rec=oclm_mdcl_rec
		   %do i=1 %to &maxdgns.;
		   icd_dgns_cd&i.=oicd_dgns_cd&i.
		   %end;;
run;

proc sort data=&tempwork..&ctyp._clm_orig&year.; by bene_id clm_cntl_num oclm_cntl_num; run;
%end;
%mend;

%pull_orig(carrier,13);
%pull_orig(hha,25);
%pull_orig(snf,25);
%pull_orig(ip,25);
%pull_orig(op,25);

* Only keeping dementia diagnoses from the original files;
%let max_ccdx=26;
%macro getccdx(ctyp);
%do year=&minyear. %to &maxyear.;
	data &tempwork..&ctyp._dem_orig&year.;
		set &tempwork..&ctyp._clm_orig&year.;

		length occdx1-occdx&max_ccdx $ 5;
		
		* Count how many dementia-related dx are found, separately by ccw list and other list;
		*	Keep thru_dt as dx_date;
		* Keep first 5 dx codes found;
		
		array diag [*] oicd_dgns_cd:;
		array ccdx [*] occdx1-occdx&max_ccdx;
		
		dxsub=0;
		
		do i=1 to dim(diag);
			if diag[i] in(&strketiaexcl) then strkeexcl=1;
			if (i<=2 and diag[i] in(&ami,&atf))
			   or (diag[i] in(&diabetes,&hyperl,&hypert)) 
			   or (diag[i] in(&strketia) and strkeexcl ne 1) then do;
				ndx=ndx+1; * Counting total number of cc diagnoses;
				found=0;
				do j=1 to dxsub;
					if diag[i]=ccdx[j] then found=j;
				end;
				if found=0 then do;
					dxsub=dxsub+1;
					if dxsub<=&maxdx then ccdx[dxsub]=diag[i];
				end;
			end;
		end;
		if ndx=0 then delete;
		
		drop oicd_dgns_cd: i j dxsub;
		
run;	
%end;
%mend getccdx;

%getccdx(hha);
%getccdx(snf);
%getccdx(op);
%getccdx(ip);
%getccdx(carrier);

* Do adjudication;
%macro adj(ctyp);
%do year=&minyear. %to &maxyear.;
* Merge to the pulled dementia codes and edit;
proc sort data=&tempwork..ccdx_&ctyp._&year. out=&tempwork..&ctyp._toedit&year.; by bene_id clm_cntl_num; run;

data &tempwork..adj_&ctyp.&year.;
	merge &tempwork..&ctyp._toedit&year. (in=a) &tempwork..&ctyp._dem_orig&year. (in=b);
	by bene_id clm_cntl_num;
	toedit=a;
	edits=b;

	array ccdx [*] ccdx1-ccdx&max_ccdx.;
	array occdx [*] occdx1-occdx&max_ccdx.;
	array nccdx [*] $ nccdx1-nccdx&max_ccdx.;

	* setting up new diagnoses;
	if first.clm_cntl_num then do;
		edit="   ";
		do i=1 to &max_ccdx.;
			nccdx[i]=ccdx[i];
			if ccdx[i] ne "" then dxcount=i;
		end;
	end;
	retain nccdx: edit dxcount;
	
	if toedit=1 and edits=1 then do;

		* adding diagnoses - clm_mdcl_rec ne 8 and clm_freq_cd not in(7,8);
		add_found=0;
		if oclm_freq_cd ne "" and oclm_freq_cd not in("7","8") and oclm_mdcl_rec ne "8" then do i=1 to &max_ccdx.;
			do j=1 to &max_ccdx.;
				if occdx[i]=nccdx[j] then add_found=1;
			end;
			if occdx[i] ne "" and add_found=0 then do;
				dxcount=dxcount+1;
				nccdx[dxcount]=occdx[i];
				substr(edit,1,1)='1';
			end;
		end;

		* replacing codes - clm_freq_cd is 7 and clm_mdcl_rec ne 8;
		if oclm_freq_cd="7" and oclm_mdcl_rec ne "8" then do i=1 to &max_ccdx.;
			nccdx[i]=occdx[i];
			substr(edit,2,1)='7';
		end;

		* deleting diagnoses - clm_mdcl_rec="8";
		delete_found=0;
		if oclm_mdcl_rec='8' then do i=1 to &max_ccdx.;
			do j=1 to &max_ccdx.;
				if occdx[i]=nccdx[j] then do;
					delete_found=1;
					nccdx[j]="";
					substr(edit,3,1)='8';
				end;
			end;
		end;

		* voiding all diagnoses - clm_freq_cd = '8' and clm_mdcl_rec ne 8;
		if oclm_freq_cd='8' and oclm_mdcl_rec ne '8' then delete;

	end;

run;

proc freq data=&tempwork..adj_&ctyp.&year.;
	table edit;
	table toedit*oclm_freq_cd;
	table toedit*edits;
run;

data &tempwork..adj_&ctyp._ck&year.;
	set &tempwork..adj_&ctyp.&year.;
	by bene_id clm_cntl_num;
	if not(first.clm_cntl_num and last.clm_cntl_num);
run;
%end;
%mend;

%adj(hha);
%adj(snf);
%adj(op);
%adj(ip);
%adj(carrier);

* Limit to last claim;
* Drop the diagnoses that we don't need and rename;
%macro finalize_adj(ctyp);
%do year=&minyear. %to &maxyear.;
proc sort data=&tempwork..adj_&ctyp.&year.; by bene_id clm_cntl_num; run;

data &tempwork..adj_&ctyp.&year.1;
	set &tempwork..adj_&ctyp.&year.;
	by bene_id clm_cntl_num;
	if toedit=1;
	if last.clm_cntl_num;
	drop oclm_cntl_num oclm_freq_cd oclm_mdcl_rec ccdx1-ccdx&max_ccdx. occdx: toedit edits i j add_found delete_found;
	rename %do i=1 %to 26; nccdx&i.=ccdx&i. %end;;	
run;

* Merge to claims that were uesd to edit and drop;
proc sort data=&tempwork..adj_&ctyp.&year.; by bene_id oclm_cntl_num; run;

data &tempwork..ccdx_&ctyp._adj_ma&year. (drop=drop oclm_freq_cd oclm_mdcl_rec toedit edits) &tempwork..&ctyp._drops&year.;
	merge &tempwork..adj_&ctyp.&year.1 (in=a) &tempwork..adj_&ctyp.&year. (in=b keep=bene_id oclm_cntl_num toedit edits oclm_freq_cd oclm_mdcl_rec
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
	if drop=1 then output &tempwork..&ctyp._drops&year.;
	else output &tempwork..ccdx_&ctyp._adj_ma&year.;
run;
%end;
%mend;

%finalize_adj(ip);
%finalize_adj(snf);
%finalize_adj(op);
%finalize_adj(hha);
%finalize_adj(carrier);

* Checking for duplicates using their 5-key edit;
/*
data &tempwork..hha_dup_check;
	set &outlib..cc_dx_hha_adj_ma15_16;
	bill_type=clm_fac_type_cd||clm_srvc_clsfctn_type_cd||clm_freq_cd;
run;

proc sort data=&tempwork..hha_dup_check; by bene_id clm_from_dt clm_thru_dt org_npi bill_type; run;

data &tempwork..hha_dup_check1;
	set &tempwork..hha_dup_check;
	by bene_id clm_from_dt clm_thru_dt org_npi bill_type;
	if not(first.bill_type and last.bill_type);
run;
*/

data &tempwork..ccdx_ma&minyear.&maxyear.;
		
		set &tempwork..ccdx_ip_adj_ma&minyear.-&tempwork..ccdx_ip_adj_ma&maxyear.
			  &tempwork..ccdx_op_adj_ma&minyear.-&tempwork..ccdx_op_adj_ma&maxyear.
			  &tempwork..ccdx_snf_adj_ma&minyear.-&tempwork..ccdx_snf_adj_ma&maxyear.
			  &tempwork..ccdx_hha_adj_ma&minyear.-&tempwork..ccdx_hha_adj_ma&maxyear.
			  &tempwork..ccdx_carrier_adj_ma&minyear.-&tempwork..ccdx_carrier_adj_ma&maxyear.;

		array cc [*] ccdx1-ccdx26;

		diabetes=0;
		hyperl=0;
		hypert=0;
		ami=0;
		atf=0;
		strketia=0;

		do i=1 to dim(cc);
			if cc[i] in(&diabetes) then diabetes=1;
			if cc[i] in(&hyperl) then hyperl=1;
			if cc[i] in(&hypert) then hypert=1;
			if cc[i] in(&ami) then ami=1;
			if cc[i] in(&atf) then atf=1;
			if cc[i] in(&strketia) then strketia=1;
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

%macro ccma(cond,refbegyr,refendyr);
proc means data=&tempwork..ccdx_ma&minyear.&maxyear. noprint nway;
	where &cond.=1 and &refbegyr.<=year(ccdx_dt)<=&refendyr.;
	class bene_id ccdx_dt;
	var ip snf op hha car;
	output out=&tempwork..ccdt_ma&cond. (drop=_type_ _freq_) max(ip snf op hha car)=;
run;

proc means data=&tempwork..ccdt_ma&cond. noprint nway;
	class bene_id;
	var ccdx_dt ip snf op hha car;
	output out=&tempwork..bene_&cond._ma (drop=_type_ _freq_) min(ccdx_dt)=first_&cond. sum(ip snf op hha car)=;
run;

data &tempwork..bene_&cond._mainc;
	set &tempwork..bene_&cond._ma;
	%if "&cond."="diabetes" %then if sum(ip,snf,hha)>=1 or sum(op,car)>=2 then ccw_diab=1;;
	%if "&cond."="hyperl" %then if sum(ip,snf,hha)>=1 or sum(op,car)>=2 then ccw_hyperl=1;;
	%if "&cond."="hypert" %then if sum(ip,snf,hha)>=1 or sum(op,car)>=2 then ccw_hypert=1;;
	%if "&cond."="atf" %then if ip>=1 or sum(op,car)>=2 then ccw_atf=1;;
	%if "&cond."="ami" %then if ip>=1 then ccw_ami=1;
	%if "&cond."="strketia" %then if ip>=1 or sum(op,car)>=2 then ccw_strketia=1;;
run;
%mend;

%ccma(diabetes,2015,2016);
%ccma(hyperl,2016,2016);
%ccma(hypert,2016,2016);
%ccma(ami,2016,2016);
%ccma(atf,2016,2016);
%ccma(strketia,2016,2016);





