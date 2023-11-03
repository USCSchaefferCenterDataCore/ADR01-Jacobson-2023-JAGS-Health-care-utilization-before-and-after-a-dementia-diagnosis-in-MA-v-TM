/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Pull Unique Inpatient Visits per month using unique bene_id, clm_thru_dt, org_npi_num;
* Input: inpatient claims 2015-2017;
* Output: monthly inpatient count;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
%macro outpatient(byear,eyear);

proc sql;
%do year=&byear %to &eyear;
	%do mo=1 %to 9;
		create table &tempwork..outpatient_&year._&mo. as
		select distinct bene_id, count(*) as hopcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt from rif&year..outpatient_claims_0&mo.)
		group by bene_id
		order by bene_id, year, month;

		create table &tempwork..carrier_&year._&mo. as
		select distinct bene_id, count(*) as carcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt from rif&year..bcarrier_claims_0&mo.)
		group by bene_id
		order by bene_id, year, month;
	%end;
	%do mo=10 %to 12;
		create table &tempwork..outpatient_&year._&mo. as
		select distinct bene_id, count(*) as hopcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt from rif&year..outpatient_claims_&mo.)
		group by bene_id
		order by bene_id, year, month;

		create table &tempwork..carrier_&year._&mo. as
		select distinct bene_id, count(*) as carcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt from rif&year..bcarrier_claims_&mo.)
		group by bene_id
		order by bene_id, year, month;
	%end;
%end;
quit;

%mend;

%outpatient(2015,2018);

%macro stack;
data &tempwork..outpatient_visitdays;
	set %do yr=2015 %to 2018;
		&tempwork..outpatient_&yr._1-&tempwork..outpatient_&yr._12
		&tempwork..carrier_&yr._1-&tempwork..carrier_&yr._12
		%end;;
	by bene_id year month;
	opcount=sum(hopcount,carcount);
run;
%mend;

%stack;

* Create permanent of beneficiary;
proc means data=&tempwork..outpatient_visitdays noprint nway;
	class bene_id year month;
	var opcount hopcount carcount;
	output out=&outlib..ffs_bene_op_visitdays (drop=_type_ _freq_) sum()=;
run;




