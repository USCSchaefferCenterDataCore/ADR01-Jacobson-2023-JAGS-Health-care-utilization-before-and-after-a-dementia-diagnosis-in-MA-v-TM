/*********************************************************************************************/
title1 'MA/ma Pilot';

* Author: PF;
* Purpose: Build Model Sample;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
data &tempwork..ffs_samp_2yrwsh1yrv &tempwork..ffs_drops_2yrwsh1yrv;
	merge base.samp_3yrffsptd_0620 (in=a keep=bene_id insamp2016-insamp2018 death_date birth_date sex race_bg age_beg2017 age_group2017 where=(insamp2017=1))
		sh054066.bene_status_year2017 (in=c keep=bene_id anydual anylis rename=(anydual=anydual2017 anylis=anylis2017))
		&outlib..dxmciincv1yrv_scendx_ffs (in=r keep=bene_id scen_dx_inc2015-scen_dx_inc2017 
			rename=(scen_dx_inc2015=plwd_inc_2015 scen_dx_inc2016=plwd_inc_2016 scen_dx_inc2017=plwd_inc_2017))
		&tempwork..bene_arthglua_ffs (in=e)
		mbsf.mbsf_cc_2016 (in=e keep=bene_id ami atrial_fib diabetes hypert hyperl stroke_tia)
		base.ltc2015_bene (in=l)
		base.ltc2016_bene (in=m)
		base.ltc2017_bene (in=n)
		base.ltc2018_bene (in=o);
		*&tempwork..mortalityddd (in=b drop=first_arthglau where=(ffs=1))		
		;
	by bene_id;

	if a;

	format birth_date death_date mmddyy10.;

	* requiring in sample until death or end of 2018;
	array insamp [2016:2018] insamp2016-insamp2018;
	
	samp_drop=0;
	do year=2017 to min(year(death_date),2018);
		if insamp[year] ne 1 then samp_drop=1;
	end;

	age_lt75=(find(age_group2017,"1."));
	age_7584=(find(age_group2017,"2."));
	age_ge85=(find(age_group2017,"3."));

	* Dummies for characteristics;
	female=(sex="2");

	race_dw=(race_bg="1");
	race_db=(race_bg="2");
	race_dh=(race_bg="5");
	race_da=(race_bg="4");
	race_dn=(race_bg="6");
	race_do=(race_bg="3");

	age_lt75=(find(age_group2017,"1."));
	age_7584=(find(age_group2017,"2."));
	age_ge85=(find(age_group2017,"3."));

	dual=(anydual2017="Y");
	lis=(anylis2017="Y");

	cc_diab=(diabetes in(1,3));
	cc_hypert=(hypert in(1,3));
	cc_hyperl=(hyperl in(1,3));
	cc_str=(stroke_tia in(1,3));
	cc_ami=(ami in(1,3));
	cc_atf=(atrial_fib in(1,3));

	* identifying incident ADRD, MCI and arthritis/glaucoma;
	if plwd_inc_2015=. and plwd_inc_2016=. then do;
		incplwd=0;
		if plwd_inc_2017 ne . then do;
			incplwd=1;
			ageincplwd=intck('year',birth_date,plwd_inc_2017,'C');
		end;
	end;

	if incplwd=0 and (first_arthglau=. or year(first_arthglau)>=2017) then do;
		incarthglau=0;
		if year(first_arthglau)=2017 then do;
			incarthglau=1;
			ageincarthglau=intck('year',birth_date,first_arthglau,'C');
		end;
	end;

	dual=(anydual2017="Y");
	lis=(anylis2017="Y");

	if first_adrddx=. then first_adrddx=plwd_inc_2017;

	* drop anyone who was in an ltc anytime in 2015-2018;
	ltc=max(of ptd2015-ptd2018,of pos2015-pos2018,of prcdr2015-prcdr2018);

	* drop anyone who died prior to plwd or arthritis/glaucoma;
	if incplwd=1 and .<death_date<first_adrddx then death_drop=1;
	if incarthglau=1 and .<death_date<first_arthglau then death_drop=1;

	if ltc=1 or samp_drop=1 or death_drop=1 then output &tempwork..ffs_drops_2yrwsh1yrv;
	else output &tempwork..ffs_samp_2yrwsh1yrv;
run;

data &tempwork..ma_samp_2yrwsh1yrv &tempwork..ma_drops_2yrwsh1yrv;
	merge base.samp_3yrmaptd_0620 (in=a keep=bene_id insamp2016-insamp2018 death_date birth_date sex race_bg age_beg2017 age_group2017 where=(insamp2017=1))
		sh054066.bene_status_year2017 (in=c keep=bene_id anydual anylis rename=(anydual=anydual2017 anylis=anylis2017))
			&outlib..dxmciincv1yrv_scendx_ma (in=r keep=bene_id scen_dx_inc2015-scen_dx_inc2017 
				rename=(scen_dx_inc2015=plwd_inc_2015 scen_dx_inc2016=plwd_inc_2016 scen_dx_inc2017=plwd_inc_2017))
			&tempwork..bene_arthglua_ma (in=e)
			&tempwork..bene_diabetes_mainc (in=f keep=bene_id ccw_diab)
			&tempwork..bene_hyperl_mainc (in=g keep=bene_id ccw_hyperl)
			&tempwork..bene_hypert_mainc (in=h keep=bene_id ccw_hypert)
			&tempwork..bene_strketia_mainc (in=i keep=bene_id ccw_strketia)
			&tempwork..bene_ami_mainc (in=j keep=bene_id ccw_ami)
			&tempwork..bene_atf_mainc (in=k keep=bene_id ccw_atf)	
		  	base.ma_ltc2015_bene (in=l)
	      	base.ma_ltc2016_bene (in=m)
			base.ma_ltc2017_bene (in=n)
			base.ma_ltc2018_bene (in=o);
			*&tempwork..mortalityddd (in=b drop=first_arthglau where=(ffs=0))	;
	by bene_id;
	if a;

	format birth_date death_date mmddyy10.;

	* requiring in sample until death or end of 2018;
	array insamp [2016:2018] insamp2016-insamp2018;
	
	samp_drop=0;
	do year=2017 to min(year(death_date),2018);
		if insamp[year] ne 1 then samp_drop=1;
	end;

	age_lt75=(find(age_group2017,"1."));
	age_7584=(find(age_group2017,"2."));
	age_ge85=(find(age_group2017,"3."));

		* Dummies for characteristics;
	female=(sex="2");

	race_dw=(race_bg="1");
	race_db=(race_bg="2");
	race_dh=(race_bg="5");
	race_da=(race_bg="4");
	race_dn=(race_bg="6");
	race_do=(race_bg="3");

	age_lt75=(find(age_group2017,"1."));
	age_7584=(find(age_group2017,"2."));
	age_ge85=(find(age_group2017,"3."));

	dual=(anydual2017="Y");
	lis=(anylis2017="Y");

	cc_diab=(ccw_diab=1);
	cc_hypert=(ccw_hypert=1);
	cc_hyperl=(ccw_hyperl=1);
	cc_str=(ccw_strketia=1);
	cc_ami=(ccw_ami=1);
	cc_atf=(ccw_atf=1);

	* identifying incident ADRD, MCI and arthritis/glaucoma;
	if plwd_inc_2015=. and plwd_inc_2016=. then do;
		incplwd=0;
		if plwd_inc_2017 ne . then do;
			incplwd=1;
			ageincplwd=intck('year',birth_date,plwd_inc_2017,'C');
		end;
	end;

	if incplwd=0 and (first_arthglau=. or year(first_arthglau)>=2017) then do;
		incarthglau=0;
		if year(first_arthglau)=2017 then do;
			incarthglau=1;
			ageincarthglau=intck('year',birth_date,first_arthglau,'C');
		end;
	end;

	dual=(anydual2017="Y");
	lis=(anylis2017="Y");

	if first_adrddx=. then first_adrddx=plwd_inc_2017;

	* drop anyone who was in an ltc anytime in 2015-2018;
	ltc=max(of ptd15-ptd18,of pos15-pos18,of prcdr15-prcdr18);

	* drop anyone who died prior to plwd or arthritis/glaucoma;
	if incplwd=1 and .<death_date<first_adrddx then death_drop=1;
	if incarthglau=1 and .<death_date<first_arthglau then death_drop=1;

	if ltc=1 or samp_drop=1 or death_drop=1 then output &tempwork..ma_drops_2yrwsh1yrv;
	else output &tempwork..ma_samp_2yrwsh1yrv;
run;

/* Export Macro */
%macro export(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/sample_1518_2yrwsh1yrv.xlsx"
	dbms=xlsx
	replace;
	sheet="&data.";
run;
%mend;

/* Stats */
proc univariate data=&tempwork..ffs_samp_2yrwsh1yrv noprint outtable=&tempwork..ffsinc_age_2yrwsh1yrv;
	var ageinc:;
run;
*%export(ffsinc_age_2yrwsh1yrv);

proc univariate data=&tempwork..ma_samp_2yrwsh1yrv noprint outtable=&tempwork..mainc_age_2yrwsh1yrv;
	var ageinc:;
run;
*%export(mainc_age_2yrwsh1yrv);

proc means data=&tempwork..ffs_samp_2yrwsh1yrv noprint nway;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd incarthglau cc:;
	output out=&tempwork..ffs_stats_2yrwsh1yrv sum()= mean()= / autoname;
run;
*%export(ffs_stats_2yrwsh1yrv);
	
proc means data=&tempwork..ffs_samp_2yrwsh1yrv noprint nway;
	where incplwd=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ffs_plwd_stats_2yrwsh1yrv sum()= mean()= / autoname;
run;
*%export(ffs_plwd_stats_2yrwsh1yrv);

proc means data=&tempwork..ffs_samp_2yrwsh1yrv noprint nway;
	where incarthglau=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ffs_arthglau_stats_2yrwsh1yrv sum()= mean()= / autoname;
run;
*%export(ffs_arthglau_stats_2yrwsh1yrv);

proc means data=&tempwork..ma_samp_2yrwsh1yrv noprint nway;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_stats_2yrwsh1yrv sum()= mean()= / autoname;
run;
*%export(ma_stats_2yrwsh1yrv);

proc means data=&tempwork..ma_samp_2yrwsh1yrv noprint nway;
	where incplwd=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_plwd_stats_2yrwsh1yrv sum()= mean()= / autoname;
run;
*%export(ma_plwd_stats_2yrwsh1yrv);

proc means data=&tempwork..ma_samp_2yrwsh1yrv noprint nway;
	where incarthglau=1;
	var female race_d: age_lt75 age_7584 age_ge85 dual lis incplwd  incarthglau cc:;
	output out=&tempwork..ma_arthglau_stats_2yrwsh1yrv sum()= mean()= / autoname;
run;
*%export(ma_arthglau_stats_2yrwsh1yrv);

/* Stats Age-Adj to match FFS */
proc freq data=&tempwork..ffs_samp_2yrwsh1yrv noprint;
	table age_beg2017 / out=&tempwork..agedist_ffs_2yrwsh1yrv (drop=count rename=percent=pct_ffs);
run;

proc freq data=&tempwork..ma_samp_2yrwsh1yrv noprint;
	table age_beg2017 / out=&tempwork..agedist_ma_2yrwsh1yrv (keep=age_beg2017 count);
run;

data &tempwork..age_weight_2yrwsh1yrv;
	merge &tempwork..agedist_ffs_2yrwsh1yrv (in=a) &tempwork..agedist_ma_2yrwsh1yrv (in=b);
	by age_beg2017;
	weight=(pct_ffs/100)/count;
run;

proc sort data=&tempwork..age_weight_2yrwsh1yrv out=&tempwork..age_weight_s_2yrwsh1yrv; by age_beg2017; run;

proc sort data=&tempwork..ma_samp_2yrwsh1yrv; by age_beg2017; run;

data &tempwork..ma_sampw_2yrwsh1yrv;
	merge &tempwork..ma_samp_2yrwsh1yrv (in=a) &tempwork..age_weight_2yrwsh1yrv (in=b);
	by age_beg2017;
	if a;
run;

proc means data=&tempwork..ma_sampw_2yrwsh1yrv noprint nway;
	weight weight;
	var incplwd  incarthglau cc:;
	output out=&tempwork..ma_sampw_stats_2yrwsh1yrv mean()= sum()= / autoname;
run;
*%export(ma_sampw_stats_2yrwsh1yrv);

* Create perm;
/*
data &outlib..ma_samp_2yrwsh1yrv;
	set &tempwork..ma_samp_2yrwsh1yrv;
run;

data &outlib..ffs_samp_2yrwsh1yrv;
	set &tempwork..ffs_samp_2yrwsh1yrv;
run;
*/
