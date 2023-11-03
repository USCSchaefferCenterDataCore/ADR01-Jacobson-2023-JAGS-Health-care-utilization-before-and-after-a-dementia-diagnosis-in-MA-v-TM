/*********************************************************************************************/
title1 'Limit sample to non-SNP beneficiaries';

* Author: PF;
* Purpose: Limit sample results to non-snp contracts;
* Input: ffs_samp_2yrwsh1yrv, ma_samp_2yrwsh1yrv;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
proc sort data=&tempwork..ffs_samp_2yrwsh1yrv; by bene_id; run;

data ffs_nonsnp;
	merge &tempwork..ffs_samp_2yrwsh1yrv (in=a) &outlib..benesnp1518 (in=b);
	by bene_id;
	if a;

	if year(death_date)=2017 then snp=max(of anysnp2015-anysnp2017);
	else if year(death_date)>2017 or year(death_date)=. then snp=max(of anysnp2015-anysnp2018);

run;

proc sort data=&tempwork..ma_samp_2yrwsh1yrv; by bene_id; run;

data ma_nonsnp;
	merge &tempwork..ma_samp_2yrwsh1yrv (in=a) &outlib..benesnp1518 (in=b);
	by bene_id;
	if a;

	if year(death_date)=2017 then snp=max(of anysnp2015-anysnp2017);
	else if year(death_date)>2017 or year(death_date)=. then snp=max(of anysnp2015-anysnp2018);

run;

/* Export Macro */
%macro export(data);
proc export data=&tempwork..&data.nonsnp
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/sample_1518_2yrwsh1yrv_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="&data._nonsnp";
run;
%mend;

/* Stats */
proc univariate data=ma_nonsnp noprint outtable=&tempwork..mainc_age_2yrwsh1yrvnonsnp;
	where snp ne 1;
	var ageinc:;
run;
%export(mainc_age_2yrwsh1yrv);

proc means data=ma_nonsnp noprint nway;
	where snp ne 1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_stats_2yrwsh1yrvnonsnp sum()= mean()= / autoname;
run;
%export(ma_stats_2yrwsh1yrv)

proc means data=ma_nonsnp noprint nway;
	where snp=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_stats_2yrwsh1yrvsnp sum()= mean()= / autoname;
run;

proc means data=ma_nonsnp noprint nway;
	where snp ne 1 and incplwd=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_plwd_stats_2yrwsh1yrvnonsnp sum()= mean()= / autoname;
run;
%export(ma_plwd_stats_2yrwsh1yrv);

proc means data=ma_nonsnp noprint nway;
	where snp ne 1 and incarthglau=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_arthglau_stats_2yrwsh1yrvnsnp sum()= mean()= / autoname;
run;

proc export data=&tempwork..ma_arthglau_stats_2yrwsh1yrvnsnp
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/sample_1518_2yrwsh1yrv_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="ma_arthglau_stats_2yrwsh1yrvnsnp";
run;

/* Stats Age-Adj to match FFS */
proc freq data=&tempwork..ffs_samp_2yrwsh1yrv noprint;
	table age_beg2017 / out=&tempwork..agedist_ffs_2yrwsh1yrv (drop=count rename=percent=pct_ffs);
run;

proc freq data=ma_nonsnp noprint;
	where snp ne 1;
	table age_beg2017 / out=&tempwork..agedist_ma_2yrwsh1yrvnonsnp (keep=age_beg2017 count);
run;

data &tempwork..age_weight_2yrwsh1yrvnonsnp;
	merge &tempwork..agedist_ffs_2yrwsh1yrv (in=a) &tempwork..agedist_ma_2yrwsh1yrvnonsnp (in=b);
	by age_beg2017;
	weight=(pct_ffs/100)/count;
run;

proc sort data=&tempwork..age_weight_2yrwsh1yrvnonsnp out=&tempwork..age_weight_s_2yrwsh1yrvnonsnp; by age_beg2017; run;

proc sort data=ma_nonsnp out=ma_nonsnp_s; where snp ne 1; by age_beg2017; run;

data ma_nonsnp_s1;
	merge ma_nonsnp_s (in=a) &tempwork..age_weight_2yrwsh1yrvnonsnp (in=b);
	by age_beg2017;
	if a;
run;

proc means data=ma_nonsnp_s1 noprint nway;
	weight weight;
	var incplwd  incarthglau cc:;
	output out=&tempwork..ma_sampw_stats_2yrwsh1yrvnonsnp mean()= sum()= / autoname;
run;
%export(ma_sampw_stats_2yrwsh1yrv);

