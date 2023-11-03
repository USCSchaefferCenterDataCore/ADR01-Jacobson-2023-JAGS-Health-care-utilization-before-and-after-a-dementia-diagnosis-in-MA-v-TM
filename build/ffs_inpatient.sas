/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Pull Unique Inpatient Visits per month using unique bene_id, clm_thru_dt, org_npi_num;
* Input: inpatient claims 2015-2017;
* Output: monthly inpatient count;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%macro inpatient(byear,eyear);

proc sql;
%do year=&byear %to &eyear;
	%do mo=1 %to 9;
		create table &tempwork..inpatient_&year._&mo. as
		select distinct bene_id, count(*) as ipcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt, org_npi_num from rif&year..inpatient_claims_0&mo.)
		group by bene_id
		order by bene_id, year, month;
	%end;
	%do mo=10 %to 12;
		create table &tempwork..inpatient_&year._&mo. as
		select distinct bene_id, count(*) as ipcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt, org_npi_num from rif&year..inpatient_claims_&mo.)
		group by bene_id
		order by bene_id, year, month;
	%end;
%end;
quit;

%mend;

%inpatient(2015,2018);

data &outlib..ffs_bene_ip1518;
	set &tempwork..inpatient_2015_1-&tempwork..inpatient_2015_12 
		&tempwork..inpatient_2016_1-&tempwork..inpatient_2016_12 
		&tempwork..inpatient_2017_1-&tempwork..inpatient_2017_12
		&tempwork..inpatient_2018_1-&tempwork..inpatient_2018_12;
	by bene_id year month;
run;

proc means data=&outlib..ffs_bene_ip1518 noprint nway;
	class year month;
	var ipcount;
	output out=&outlib..ffs_ip1518 (drop=_type_ _freq_) sum()=;
run;





