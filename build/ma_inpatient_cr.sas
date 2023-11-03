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
%macro mainpatient(byear,eyear);

proc sql;
%do year=&byear %to &eyear;
		create table &tempwork..mainpatient_&year. as
		select distinct bene_id, count(*) as ipcount, month(clm_thru_dt) as month, &year. as year
		from (select distinct bene_id, clm_thru_dt, org_npi from enrfpl&year..ip_base_enc)
		group by bene_id, year, month
		order by bene_id, year, month;
%end;
quit;

%mend;

%mainpatient(15,18);

data &tempwork..mainpatient1518;
	set &tempwork..mainpatient_15
	    &tempwork..mainpatient_16
	    &tempwork..mainpatient_17
		&tempwork..mainpatient_18;
	by bene_id year month;
	year=year+2000;
run;

proc means data=&tempwork..mainpatient1518 noprint nway;
	class year month;
	var ipcount;
	output out=&outlib..ma_ip1518 (drop=_type_ _freq_) sum()=;
run;

data &outlib..ma_bene_ip1518;
	&tempwork..mainpatient1518;
run;





