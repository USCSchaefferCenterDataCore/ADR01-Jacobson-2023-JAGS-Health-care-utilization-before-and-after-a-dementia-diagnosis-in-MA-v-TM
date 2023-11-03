/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Pull Unique Inpatient Visits per month using unique bene_id, clm_thru_dt, org_npi_num;
* Input: inpatient claims 2015-2017;
* Output: monthly inpatient count;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%macro outpatient(byear,eyear);

proc sql;
%do year=&byear %to &eyear;
	%do mo=1 %to 9;
		create table &tempwork..outpatient_&year._&mo. as
		select distinct bene_id, count(*) as hopcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt, org_npi_num from rif&year..outpatient_claims_0&mo.)
		group by bene_id
		order by bene_id, year, month;

		create table &tempwork..carrier_&year._&mo. as
		select distinct bene_id, count(*) as carcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt, carr_clm_blg_npi_num from rif&year..bcarrier_claims_0&mo.)
		group by bene_id
		order by bene_id, year, month;
	%end;
	%do mo=10 %to 12;
		create table &tempwork..outpatient_&year._&mo. as
		select distinct bene_id, count(*) as hopcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt, org_npi_num from rif&year..outpatient_claims_&mo.)
		group by bene_id
		order by bene_id, year, month;

		create table &tempwork..carrier_&year._&mo. as
		select distinct bene_id, count(*) as carcount, &mo. as month, &year. as year
		from (select distinct bene_id, clm_thru_dt, carr_clm_blg_npi_num from rif&year..bcarrier_claims_&mo.)
		group by bene_id
		order by bene_id, year, month;
	%end;
%end;
quit;

%do year=&byear. %to &year.;
data &tempwork..outpatient&year.;
	set &tempwork..outpatient_&year._1-&tempwork..outpatient_&year._12
		&tempwork..carrier_&year._1-&tempwork..carrier_&year._12;
	by bene_id year month;
	opcount=sum(hopcount,carcount);
run;

proc means data=&tempwork..outpatient&year. noprint nway;
	class year month;
	var opcount hopcount carcount;
	output out=&tempwork..ffs_op&year. (drop=_type_ _freq_) sum()=;
run;

* Create permanent of beneficiary;
proc means data=&tempwork..outpatient&year. noprint nway;
	class bene_id year month;
	var opcount hopcount carcount;
	output out=&tempwork..ffs_bene_op&year. (drop=_type_ _freq_) sum()=;
run;
%end;

%mend;

%outpatient(2015,2018);

data &outlib..ffs_op1518;
	set &tempwork..ffs_op2015-&tempwork..ffs_op2018;
	by year month;
run;

data &outlib..ffs_bene_op1518;
	set &tempwork..ffs_bene_op2015-&tempwork..ffs_bene_op2018;
	by bene_id year month;
run;




