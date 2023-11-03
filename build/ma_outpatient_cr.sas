/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Pull Unique Inpatient Visits per month using unique bene_id, clm_thru_dt, org_npi_num;
* Input: inpatient claims 2015-2018;
* Output: monthly inpatient count;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
%macro maoutpatient(byear,eyear);

proc sql;
%do year=&byear %to &eyear;
		create table &tempwork..maoutpatient_&year. as
		select distinct bene_id, count(*) as hopcount, month(clm_thru_dt) as month, &year. as year
		from (select distinct bene_id, clm_thru_dt, org_npi from enrfpl&year..op_base_enc)
		group by bene_id, year, month
		order by bene_id, year, month;

		create table &tempwork..macarrier_&year. as
		select distinct bene_id, count(*) as carcount, month(clm_thru_dt) as month, &year. as year
		from (select distinct bene_id, clm_thru_dt, org_npi from enrfpl&year..carrier_base_enc)
		group by bene_id, year, month
		order by bene_id, year, month;
%end;
quit;

data &tempwork..maoutpatient1518;
	set %do year=&byear. %to &year.
		&tempwork..maoutpatient_&year.
		&tempwork..macarrier_&year.
	%end;;
	by bene_id year month;
	opcount=sum(hopcount,carcount);
	year=year+2000;
run;

%mend;

%maoutpatient(15,18);

proc means data=&tempwork..maoutpatient1518 noprint nway;
	class year month;
	var opcount hopcount carcount;
	output out=&tempwork..ma_op1518 (drop=_type_ _freq_) sum()=;
run;

data &outlib..ma_op1518;
	set &tempwork..ma_op1518;
run;

* Create permanent of beneficiary;
proc means data=&tempwork..maoutpatient1518 noprint nway;
	class bene_id bene_id year month;
	var opcount hopcount carcount;
	output out=&tempwork..ma_bene_op1518 (drop=_type_ _freq_) sum()=;
run;

data &outlib..ma_bene_op1518;
	set &tempwork..ma_bene_op1518;
run;

