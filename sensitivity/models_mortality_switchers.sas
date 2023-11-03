/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Modeling Mortality after one year - allow switching;
* Input: quarterly;
* Output: ;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/
options obs=max;
data &tempwork..switch_plwd_mort;
	set &tempwork..switch_2yrwsh1yrv (in=a where=(incplwd=1) keep=bene_id incplwd first_adrddx ffs death_date age_beg female race_d: cc_: dual lis);
	by bene_id;

	* month of first date;
	month=month(first_adrddx);
	year=year(first_adrddx);

	* Getting three year age bands;
	array age3y [*] age3y1-age3y8;

	do i=1 to dim(age3y);
		age3y[i]=0;
		if sum(3*i,66,-3)<age_beg<=sum(3*i,66) then do;
			age3y[i]=1;
			agecat=i;
		end;
	end;
	age3y9=0;
	if age_beg>90 then do;
		age3y9=1;
		agecat=9;
	end;


	* surv;
	surv=0;
	if death_date=. or intck('day',first_adrddx,death_date)>=365 then surv=1;

run;

data &tempwork..switch_arthglau_mort;
	set &tempwork..switch_2yrwsh1yrv (in=a where=(incarthglau) keep=bene_id first_arthglau incarthglau ffs death_date age_beg female race_d: cc_: dual lis);
	by bene_id;

	* month of first date;
	month=month(first_arthglau);
	year=year(first_arthglau);

	* Getting three year age bands;
	array age3y [*] age3y1-age3y8;

	do i=1 to dim(age3y);
		age3y[i]=0;
		if sum(3*i,66,-3)<age_beg<=sum(3*i,66) then do;
			age3y[i]=1;
			agecat=i;
		end;
	end;
	age3y9=0;
	if age_beg>90 then do;
		age3y9=1;
		agecat=9;
	end;

	* surv;
	surv=0;
	if death_date=. or intck('day',first_arthglau,death_date)>=365 then surv=1;

run;

proc sort data=&tempwork..switch_plwd_mort; by bene_id year month; run;
proc sort data=&tempwork..switch_arthglau_mort; by bene_id year month; run;

data &tempwork..switch_plwd_mort1;
	merge &tempwork..switch_plwd_mort (in=a) maffs.ma_bene_ip1518 (in=b rename=(ipcount=ipcount_ma)) maffs.ffs_bene_ip1518 (in=c rename=(ipcount=ipcount_ffs));
	by bene_id year month;
	if a;
	ipinqtr0=(b or c);
run;

data &tempwork..switch_arthglau_mort1;
	merge &tempwork..switch_arthglau_mort (in=a) maffs.ma_bene_ip1518 (in=b rename=(ipcount=ipcount_ma)) maffs.ffs_bene_ip1518 (in=c rename=(ipcount=ipcount_ffs));
	by bene_id year month;
	if a;
	ipinqtr0=(b or c);
run;

* Add location;

data &tempwork..switch_ffsplwdinc &tempwork..switch_ffsarthglauinc &tempwork..switch_maplwdinc &tempwork..switch_maarthglauinc;
	set &tempwork..switch_plwd_mort1 (in=a) &tempwork..switch_arthglau_mort1 (in=b);
	plwd=a;
	inc=max(first_adrddx,first_arthglau);
	format inc mmddyy10.;
	if ffs=1 then do;
		if plwd=1 then output &tempwork..switch_ffsplwdinc;
		else output &tempwork..switch_ffsarthglauinc;
	end;
	else do;
		if plwd=1 then output &Tempwork..switch_maplwdinc;
		else output &tempwork..switch_maarthglauinc;
	end;
	keep bene_id inc ffs plwd;
run;

* SQL to pull;
proc sql;
	create table &tempwork..switch_ffsplwdinc1 as
	select x.*, y.*,(find(y.claim_types,'1')) as ipincdx
	from &tempwork..switch_ffsplwdinc as x left join demdx.dementia_dt_1999_2020 (keep=bene_id demdx_dt claim_types demdx: where=(year(demdx_dt)=2017)) as y
	on x.bene_id=y.bene_id and x.inc=y.demdx_dt;
quit;

proc sql;
	create table &tempwork..switch_maplwdinc1 as
	select x.*, y.*,(find(y.claim_types,'1')) as ipincdx
	from &tempwork..switch_maplwdinc as x left join demdx.dementia_dt_ma15_18 (keep=bene_id clm_thru_dt claim_types demdx: where=(year(clm_thru_dt)=2017)) as y
	on x.bene_id=y.bene_id and x.inc=y.clm_thru_dt;
quit;

proc sql;
	create table &tempwork..switch_ffsarthglauinc1 as
	select x.*, y.*, (find(y.clm_typ,'1')) as ipincdx
	from &tempwork..switch_ffsarthglauinc as x left join &tempwork..arthglau_dx_2015_2018 (keep=bene_id arthglaudx_dt clm_typ arthglaudx: where=(year(arthglaudx_dt)=2017)) as y
	on x.bene_id=y.bene_id and x.inc=y.arthglaudx_dt;
quit;

proc sql;
	create table &tempwork..switch_maarthglauinc1 as
	select x.*, y.clm_typ,y.arthglaudx1,(find(y.clm_typ,'1')) as ipincdx
	from &tempwork..switch_maarthglauinc as x left join &tempwork..arthglaudx_ma15_18(keep=bene_id arthglaudx_dt clm_typ arthglaudx: where=(year(arthglaudx_dt)=2017)) as y
	on x.bene_id=y.bene_id and x.inc=y.arthglaudx_dt;
quit;

* Stack and compare;
data &tempwork..switch_ipincdx;
	set &tempwork..switch_ffsplwdinc1 (keep=bene_id ipincdx) &tempwork..switch_maplwdinc1 (keep=bene_id ipincdx)
		&tempwork..switch_ffsarthglauinc1 (keep=bene_id ipincdx) 
		&tempwork..switch_maarthglauinc1 (keep=bene_id ipincdx);
run;

proc means data=&tempwork..switch_ipincdx noprint nway;
	class bene_id;
	output out=&tempwork..switch_ipincdx_bene (drop=_type_ _freq_) max(ipincdx)=;
run;

data &tempwork..switch_plwd_mort1;
	merge &tempwork..switch_plwd_mort1 (in=a) &tempwork..switch_ipincdx_bene;
	by bene_id;
	if a;
run;

data &tempwork..switch_arthglau_mort1;
	merge &tempwork..switch_arthglau_mort1 (in=a) &tempwork..switch_ipincdx_bene;
	by bene_id;
	if a;
run;


%macro switch_mortmodels(cond,out,cov=);
ods output parameterestimates=&tempwork..switch_&cond._&out.est;
ods output oddsratios=&tempwork..switch_&cond._&out.or;
proc logistic data=&tempwork..switch_&cond._mort1;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..switch_&cond._&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality_switch.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.est";
run;

proc export data=&tempwork..switch_&cond._&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality_switch.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.or";
run;
%mend;

%switch_mortmodels(plwd,base);
%switch_mortmodels(plwd,ses,cov=dual lis);
%switch_mortmodels(plwd,cc,cov=dual lis cc_:);
%switch_mortmodels(plwd,loc,cov=dual lis cc_: ipincdx);

%switch_mortmodels(arthglau,base);
%switch_mortmodels(arthglau,ses,cov=dual lis);
%switch_mortmodels(arthglau,cc,cov=dual lis cc_:);
%switch_mortmodels(arthglau,loc,cov=dual lis cc_: ipincdx);


data &tempwork..switch_mortalityddd;
	set &tempwork..switch_plwd_mort1 (in=a) &tempwork..switch_arthglau_mort1 (in=b) ;

	* plwd;
	plwd=a;

	*plwd*ffs;
	plwdffs=plwd*ffs;

run;

proc means data=&tempwork..switch_mortalityddd noprint;
	class plwd ffs ipinqtr0;
	var female race_d: age3y: cc: surv;
	output out=&tempwork..switch_mortddd_samp sum()= mean()= /autoname;
run;

proc export data=&tempwork..switch_mortddd_samp
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_switch.xlsx"
	dbms=xlsx
	replace;
	sheet="switch_mortddd_samp";
run;

%macro switch_dddmortmodels(out,cov=);
* full sample;
ods output parameterestimates=&tempwork..switch_mortddd_&out.est;
ods output oddsratios=&tempwork..switch_mortddd_&out.or;
proc logistic data=&tempwork..switch_mortalityddd;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..switch_mortddd_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_switch.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.est";
run;

proc export data=&tempwork..switch_mortddd_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_switch.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.or";
run;

* sample with hospitalization in qtr 0;
ods output parameterestimates=&tempwork..switch_mortdddip_&out.est;
ods output oddsratios=&tempwork..switch_mortdddip_&out.or;
proc logistic data=&tempwork..switch_mortalityddd;
	where ipinqtr0=1;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..switch_mortdddip_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_switch.xlsx"
	dbms=xlsx
	replace;
	sheet="switch_mortdddip_&out.est";
run;

proc export data=&tempwork..switch_mortdddip_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_switch.xlsx"
	dbms=xlsx
	replace;
	sheet="switch_mortdddip_&out.or";
run;
%mend;

%switch_dddmortmodels(base);
%switch_dddmortmodels(ses,cov=dual lis);
%switch_dddmortmodels(cc,cov=dual lis cc_:);

proc sort data=&tempwork..switch_mortalityddd; by bene_id; run;

data &tempwork..switch_mortalityddd_loc;
	merge &tempwork..switch_mortalityddd (in=a) &tempwork..switch_ipincdx_bene (in=b keep=bene_id ipincdx);
	by bene_id;
run;

* full sample;
%let out=loc;
%let cov=dual lis cc_: ipincdx;
ods output parameterestimates=&tempwork..switch_mortddd_&out.est;
ods output oddsratios=&tempwork..switch_mortddd_&out.or;
proc logistic data=&tempwork..switch_mortalityddd_loc;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..switch_mortddd_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_switch.xlsx"
	dbms=xlsx
	replace;
	sheet="switch_mortddd_&out.est";
run;

proc export data=&tempwork..switch_mortddd_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_switch.xlsx"
	dbms=xlsx
	replace;
	sheet="switch_mortddd_&out.or";
run;

proc sort data=&tempwork..switch_mortalityddd; by bene_id; run;

data &tempwork..switch_mortalityddd_loc;
	merge &tempwork..switch_mortalityddd (in=a) &outlib..ipincdx_bene (in=b keep=bene_id ipincdx);
	by bene_id;
	loc=b;
run;
