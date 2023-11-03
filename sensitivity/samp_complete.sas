/*********************************************************************************************/
title1 'Highly Complete Contracts';

* Author: PF;
* Purpose: Limit sample results to highly complete contracts;
* Input: ffs_samp_2yrwsh1yrv, ma_samp_2yrwsh1yrv;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
proc sort data=&tempwork..ma_samp_2yrwsh1yrv; by bene_id; run;

data macomplete;
	merge &tempwork..ma_samp_2yrwsh1yrv (in=a) &outlib..benecomplete1518 (in=b);
	by bene_id;
	if a;

	if year(death_date)=2017 then complete=max(of complete2015-complete2017);
	else if year(death_date)>2017 or year(death_date)=. then complete=max(of complete2015-complete2018);

run;

/* Export Macro */
%macro export(data);
proc export data=&tempwork..&data.c
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/sample_1518_2yrwsh1yrv_c.xlsx"
	dbms=xlsx
	replace;
	sheet="&data._c";
run;
%mend;

/* Stats */
proc univariate data=macomplete noprint outtable=&tempwork..mainc_age_2yrwsh1yrvc;
	where complete;
	var ageinc:;
run;
%export(mainc_age_2yrwsh1yrv);

proc means data=macomplete noprint nway;
	where complete=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_stats_2yrwsh1yrvc sum()= mean()= / autoname;
run;
%export(ma_stats_2yrwsh1yrv)

proc means data=macomplete noprint nway;
	where complete=1 and incplwd=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_plwd_stats_2yrwsh1yrvc sum()= mean()= / autoname;
run;
%export(ma_plwd_stats_2yrwsh1yrv);

proc means data=macomplete noprint nway;
	where complete=1 and incarthglau=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_arthglau_stats_2yrwsh1yrvc sum()= mean()= / autoname;
run;
%export(ma_arthglau_stats_2yrwsh1yrv);

/* Stats Age-Adj to match FFS */
proc freq data=&tempwork..ffs_samp_2yrwsh1yrv noprint;
	table age_beg2017 / out=&tempwork..agedist_ffs_2yrwsh1yrv (drop=count rename=percent=pct_ffs);
run;

proc freq data=macomplete noprint;
	where complete=1;
	table age_beg2017 / out=&tempwork..agedist_ma_2yrwsh1yrvc (keep=age_beg2017 count);
run;

data &tempwork..age_weight_2yrwsh1yrvc;
	merge &tempwork..agedist_ffs_2yrwsh1yrv (in=a) &tempwork..agedist_ma_2yrwsh1yrvc (in=b);
	by age_beg2017;
	weight=(pct_ffs/100)/count;
run;

proc sort data=&tempwork..age_weight_2yrwsh1yrvc out=&tempwork..age_weight_s_2yrwsh1yrvc; by age_beg2017; run;

proc sort data=macomplete out=macomplete_s; where complete=1; by age_beg2017; run;

data macomplete_s1;
	merge macomplete_s (in=a) &tempwork..age_weight_2yrwsh1yrv (in=b);
	by age_beg2017;
	if a;
run;

proc means data=macomplete_s1 noprint nway;
	weight weight;
	var incplwd  incarthglau cc:;
	output out=&tempwork..ma_sampw_stats_2yrwsh1yrvc mean()= sum()= / autoname;
run;
%export(ma_sampw_stats_2yrwsh1yrv);

