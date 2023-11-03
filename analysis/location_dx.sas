/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Identify location of incident dementia diagnosis;
* Input: ffs_samp_2yrwsh1yrv, ma_samp_2yrwsh1yrv;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
* Merge to dementia dx and find the location of the claim;
proc sql;
	create table ffs_inc as
	select x.bene_id, x.plwd_inc_2017, y.claim_types
	from &tempwork..ffs_samp_2yrwsh1yrv (where=(incplwd=1)) x
	left join demdx.dementia_dt_1999_2021 y
	on x.bene_id=y.bene_id and x.plwd_inc_2017=y.demdx_dt;
quit;

proc sql;
	create table ma_inc as
	select x.bene_id, x.plwd_inc_2017, y.claim_types
	from &tempwork..ma_samp_2yrwsh1yrv (where=(incplwd=1)) x
	left join demdx.dementia_dt_ma15_18 y
	on x.bene_id=y.bene_id and x.plwd_inc_2017=y.clm_thru_dt;
quit;

* Separate out to merge to original claim;
data ffs_inc_op ffs_inc_car ffs_inc_ip ffs_inc_hha ffs_inc_snf;
	set ffs_inc;
	if find(claim_types,'1') then output ffs_inc_ip;
	if find(claim_types,'2') then output ffs_inc_snf;
	if find(claim_types,'3') then output ffs_inc_op;
	if find(claim_types,'4') then output ffs_inc_hha;
	if find(claim_types,'5') then output ffs_inc_car;
run;

data ma_inc_op ma_inc_car ma_inc_ip ma_inc_hha ma_inc_snf;
	set ma_inc;
	if find(claim_types,'1') then output ma_inc_ip;
	if find(claim_types,'2') then output ma_inc_snf;
	if find(claim_types,'3') then output ma_inc_op;
	if find(claim_types,'4') then output ma_inc_hha;
	if find(claim_types,'5') then output ma_inc_car;
run;

%macro ffsrev(typ,input,keep=);
data ffsrev_&typ.;
	set %do mo=1 %to 9;
		rif2017.&input._0&mo. (keep=bene_id clm_thru_dt &keep)
		%end;
		%do mo=10 %to 12;
		rif2017.&input._&mo. (keep=bene_id clm_thru_dt &keep)
		%end;;
run;
%mend;

%ffsrev(ip,inpatient_revenue,keep=rev_cntr);
%ffsrev(op,outpatient_revenue,keep=rev_cntr);
%ffsrev(hha,hha_revenue,keep=rev_cntr);
%ffsrev(snf,snf_revenue,keep=rev_cntr);
%ffsrev(car,bcarrier_line,keep=line_place_of_srvc_cd line_icd_dgns_cd);

%macro loc(samp,typ,var,input);
%if "&samp."="ffs" %then %do;
proc sql;
	%do mo=1 %to 9;
	create table &samp.rev_inc_&typ.&mo. as
	select x.*, y.*
	from &samp._inc_&typ. as x left join rif2017.&input._0&mo. (keep=bene_id clm_thru_dt &var.) as y
	on x.bene_id=y.bene_id and x.plwd_inc_2017=y.clm_thru_dt;
	%end;
	%do mo=10 %to 12;
	create table &samp.rev_inc_&typ.&mo. as
	select x.*, y.*
	from &samp._inc_&typ. as x left join rif2017.&input._&mo. (keep=bene_id clm_thru_dt &var.) as y
	on x.bene_id=y.bene_id and x.plwd_inc_2017=y.clm_thru_dt;
	%end;
quit;
%end;
%if "&samp."="ma" %then %do;
proc sql;
	create table &samp.rev_inc_&typ. as
	select x.*, y.*
	from &samp._inc_&typ. as x left join &input (keep=bene_id clm_thru_dt &var.) as y
	on x.bene_id=y.bene_id and x.plwd_inc_2017=y.clm_thru_dt;
quit;
%end;
%mend;

%loc(ffs,ip,rev_cntr,inpatient_revenue);
%loc(ffs,op,rev_cntr,outpatient_revenue);
%loc(ffs,hha,rev_cntr,hha_revenue);
%loc(ffs,snf,rev_cntr,snf_revenue);
%loc(ffs,car,line_place_of_srvc_cd line_icd_dgns_cd,bcarrier_line);
%loc(ma,ip,rev_cntr,enrfpl17.ip_revenue_enc);
%loc(ma,op,rev_cntr,enrfpl17.op_revenue_enc);
%loc(ma,hha,rev_cntr,enrfpl17.hha_revenue_enc);
%loc(ma,snf,rev_cntr,enrfpl17.snf_revenue_enc);
%loc(ma,car,clm_place_of_srvc_cd icd_dgns_cd:,enrfpl17.carrier_base_enc);

* Remove the claims from the carrier that don't have a dementia dx;
***** Defining ICD-10 using new 2017 30 CCW definition;
%let ccw_dx10="F0150" "F0151" "F0280" "F0281" "F0390" "F0391" "F04" "G132" "G138" "F05"
							"F061" "F068" "G300" "G301" "G308" "G309" "G311" "G312" "G3101" "G3109"
							"G914" "G94" "R4181" "R54" "G3184";

data marev_inc_cardem;
	set marev_inc_car;
	array dx [*] icd_dgns_cd:;
	do i=1 to dim(dx);
		if dx[i] in(&ccw_dx10) then keep=1;
	end;
	if keep;
run;

data ffsrev_inc_cardem;
	set ffsrev_inc_car1-ffsrev_inc_car12;
	if line_icd_dgns_cd in(&ccw_dx10);
run;

* Stack all together;
data ffsrev;
	set ffsrev_inc_op1-ffsrev_inc_op12 ffsrev_inc_snf1-ffsrev_inc_snf12 
		ffsrev_inc_cardem ffsrev_inc_hha1-ffsrev_inc_hha12 ffsrev_inc_ip1-ffsrev_inc_ip12;
run;

data marev;
	set marev_inc_op marev_inc_snf marev_inc_cardem marev_inc_hha marev_inc_ip;
run;

proc freq data=ffsrev noprint order=freq;
	table rev_cntr / out=ffsrev_freq missing;
	table line_place_of_srvc_cd / out=ffspos_freq missing;
run;

proc freq data=marev noprint order=freq;
	table rev_cntr / out=marev_freq missing;
	table clm_place_of_srvc_cd / out=mapos_freq missing;
run;

proc export data=ffsrev_freq
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/location_dx.xlsx"
	dbms=xlsx
	replace;
	sheet="ffsrev";
run;

proc export data=marev_freq
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/location_dx.xlsx"
	dbms=xlsx
	replace;
	sheet="marev";
run;

proc export data=ffspos_freq
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/location_dx.xlsx"
	dbms=xlsx
	replace;
	sheet="ffspos";
run;

proc export data=mapos_freq
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/location_dx.xlsx"
	dbms=xlsx
	replace;
	sheet="mapos";
run;


* Only doing for inpatient;
data ffsrev_ip;
	set ffsrev_inc_ip1-ffsrev_inc_ip12;
run;

proc freq data=ffsrev_ip noprint order=freq;
	table rev_cntr / out=ffsiprev_freq missing;
run;

proc freq data=marev_inc_ip noprint order=freq;
	table rev_cntr / out=maiprev_freq missing;
run;

proc export data=ffsiprev_freq
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/location_dx.xlsx"
	dbms=xlsx
	replace;
	sheet="ffsip";
run;

proc export data=maiprev_freq
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/location_dx.xlsx"
	dbms=xlsx
	replace;
	sheet="maip";
run;






