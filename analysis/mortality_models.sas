/*********************************************************************************************/
title1 'MA/FFS Pilot';

* Author: PF;
* Purpose: Modeling Mortality after one year;
* Input: quarterly;
* Output: ;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

data &tempwork..plwd_mort;
	set &outlib..ffs_mocd2 (in=a where=(mosfrmplwd=0) keep=bene_id first_adrddx death_date age3y2-age3y9 female race_d: cc_: dualmo lismo mosfrmplwd )
		&outlib..ma_mocd2 (in=b where=(mosfrmplwd=0) keep=bene_id first_adrddx death_date age3y2-age3y9 female race_d: cc_: dualmo lismo mosfrmplwd );

	ffs=a;

	* month of first date;
	month=month(first_adrddx);
	year=year(first_adrddx);

	* surv;
	surv=0;
	if death_date=. or intck('day',first_adrddx,death_date)>=365 then surv=1;

run;

data &tempwork..arthglau_mort;
	set &outlib..ffs_mocd2 (in=a where=(mosfrmarthglau=0) keep=bene_id first_arthglau death_date age3y2-age3y9 female race_d: cc_: dualmo lismo mosfrmarthglau )
		&outlib..ma_mocd2 (in=b where=(mosfrmarthglau=0) keep=bene_id first_arthglau death_date age3y2-age3y9 female race_d: cc_: dualmo lismo mosfrmarthglau);

	ffs=a;

	* month of first date;
	month=month(first_arthglau);
	year=year(first_arthglau);

	* surv;
	surv=0;
	if death_date=. or intck('day',first_arthglau,death_date)>=365 then surv=1;

run;

proc sort data=&tempwork..plwd_mort; by bene_id year month; run;
proc sort data=&tempwork..arthglau_mort; by bene_id year month; run;

data &tempwork..plwd_mort1;
	merge &tempwork..plwd_mort (in=a) maffs.ma_bene_ip1518 (in=b rename=(ipcount=ipcount_ma)) maffs.ffs_bene_ip1518 (in=c rename=(ipcount=ipcount_ffs));
	by bene_id year month;
	if a;
	ipinqtr0=(b or c);
run;

data &tempwork..arthglau_mort1;
	merge &tempwork..arthglau_mort (in=a) maffs.ma_bene_ip1518 (in=b rename=(ipcount=ipcount_ma)) maffs.ffs_bene_ip1518 (in=c rename=(ipcount=ipcount_ffs));
	by bene_id year month;
	if a;
	ipinqtr0=(b or c);
run;

%macro mortmodels(cond,out,cov=);
ods output parameterestimates=&tempwork..&cond._&out.est;
ods output oddsratios=&tempwork..&cond._&out.or;
proc logistic data=&tempwork..&cond._mort;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..&cond._&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.est";
run;

proc export data=&tempwork..&cond._&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.or";
run;

* Sample with IP in month 0;
ods output parameterestimates=&tempwork..&cond.ip_&out.est;
ods output oddsratios=&tempwork..&cond.ip_&out.or;
proc logistic data=&tempwork..&cond._mort1;
	where ipinqtr0=1;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..&cond.ip_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond.ip_&out.est";
run;

proc export data=&tempwork..&cond.ip_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond.ip_&out.or";
run;
%mend;


%mortmodels(plwd,base);
%mortmodels(plwd,ses,cov=dualmo lismo);
%mortmodels(plwd,cc,cov=dualmo lismo cc_:);

%mortmodels(arthglau,base);
%mortmodels(arthglau,ses,cov=dualmo lismo);
%mortmodels(arthglau,cc,cov=dualmo lismo cc_:);


* By subgroup;
%macro mortmodelssub(cond,out,subgroup,outsub,val,cov=);
ods output parameterestimates=&tempwork..&cond._&out.est&outsub.;
ods output oddsratios=&tempwork..&cond._&out.or&outsub.;
proc logistic data=&tempwork..&cond._mort;
	where &subgroup.=&val.;
	class age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..&cond._&out.est&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.est&outsub.";
run;

proc export data=&tempwork..&cond._&out.or&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.or&outsub.";
run;

* Sample with IP in month 0;
ods output parameterestimates=&tempwork..&cond.ip_&out.est&outsub.;
ods output oddsratios=&tempwork..&cond.ip_&out.or&outsub.;
proc logistic data=&tempwork..&cond._mort1;
	where ipinqtr0=1 and &subgroup.=&val.;;
	class age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..&cond.ip_&out.est&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond.ip_&out.est&outsub.";
run;

proc export data=&tempwork..&cond.ip_&out.or&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond.ip_&out.or&outsub.";
run;
%mend;

* PLWD;
%mortmodelssub(plwd,base,race_dw,w,1,cov=female);
%mortmodelssub(plwd,ses,race_dw,w,1,cov=female dualmo lismo);
%mortmodelssub(plwd,cc,race_dw,w,1,cov=female dualmo lismo cc_:);

%mortmodelssub(plwd,base,race_db,b,1,cov=female);
%mortmodelssub(plwd,ses,race_db,b,1,cov=female dualmo lismo);
%mortmodelssub(plwd,cc,race_db,b,1,cov=female dualmo lismo cc_:);

%mortmodelssub(plwd,base,race_dh,h,1,cov=female);
%mortmodelssub(plwd,ses,race_dh,h,1,cov=female dualmo lismo);
%mortmodelssub(plwd,cc,race_dh,h,1,cov=female dualmo lismo cc_:);

%mortmodelssub(plwd,base,race_da,a,1,cov=female);
%mortmodelssub(plwd,ses,race_da,a,1,cov=female dualmo lismo);
%mortmodelssub(plwd,cc,race_da,a,1,cov=female dualmo lismo cc_:);

%mortmodelssub(plwd,base,race_dn,n,1,cov=female);
%mortmodelssub(plwd,ses,race_dn,n,1,cov=female dualmo lismo);
%mortmodelssub(plwd,cc,race_dn,n,1,cov=female dualmo lismo cc_:);

%mortmodelssub(plwd,base,race_do,o,1,cov=female);
%mortmodelssub(plwd,ses,race_do,o,1,cov=female dualmo lismo);
%mortmodelssub(plwd,cc,race_do,o,1,cov=female dualmo lismo cc_:);

%mortmodelssub(plwd,base,female,f,1,cov=race_db race_dh race_da race_do race_dn );
%mortmodelssub(plwd,ses,female,f,1,cov=race_db race_dh race_da race_do race_dn  dualmo lismo);
%mortmodelssub(plwd,cc,female,f,1,cov=race_db race_dh race_da race_do race_dn  dualmo lismo cc_:);

%mortmodelssub(plwd,base,female,m,0,cov=race_db race_dh race_da race_do race_dn );
%mortmodelssub(plwd,ses,female,m,0,cov=race_db race_dh race_da race_do race_dn  dualmo lismo);
%mortmodelssub(plwd,cc,female,m,0,cov=race_db race_dh race_da race_do race_dn  dualmo lismo cc_:);

* arthglau;
%mortmodelssub(arthglau,base,race_dw,w,1,cov=female);
%mortmodelssub(arthglau,ses,race_dw,w,1,cov=female dualmo lismo);
%mortmodelssub(arthglau,cc,race_dw,w,1,cov=female dualmo lismo cc_:);

%mortmodelssub(arthglau,base,race_db,b,1,cov=female);
%mortmodelssub(arthglau,ses,race_db,b,1,cov=female dualmo lismo);
%mortmodelssub(arthglau,cc,race_db,b,1,cov=female dualmo lismo cc_:);

%mortmodelssub(arthglau,base,race_dh,h,1,cov=female);
%mortmodelssub(arthglau,ses,race_dh,h,1,cov=female dualmo lismo);
%mortmodelssub(arthglau,cc,race_dh,h,1,cov=female dualmo lismo cc_:);

%mortmodelssub(arthglau,base,race_da,a,1,cov=female);
%mortmodelssub(arthglau,ses,race_da,a,1,cov=female dualmo lismo);
%mortmodelssub(arthglau,cc,race_da,a,1,cov=female dualmo lismo cc_:);

%mortmodelssub(arthglau,base,race_dn,n,1,cov=female);
%mortmodelssub(arthglau,ses,race_dn,n,1,cov=female dualmo lismo);
%mortmodelssub(arthglau,cc,race_dn,n,1,cov=female dualmo lismo cc_:);

%mortmodelssub(arthglau,base,race_do,o,1,cov=female);
%mortmodelssub(arthglau,ses,race_do,o,1,cov=female dualmo lismo);
%mortmodelssub(arthglau,cc,race_do,o,1,cov=female dualmo lismo cc_:);

%mortmodelssub(arthglau,base,female,f,1,cov=race_db race_dh race_da race_do race_dn );
%mortmodelssub(arthglau,ses,female,f,1,cov=race_db race_dh race_da race_do race_dn  dualmo lismo);
%mortmodelssub(arthglau,cc,female,f,1,cov=race_db race_dh race_da race_do race_dn  dualmo lismo cc_:);

%mortmodelssub(arthglau,base,female,m,0,cov=race_db race_dh race_da race_do race_dn );
%mortmodelssub(arthglau,ses,female,m,0,cov=race_db race_dh race_da race_do race_dn  dualmo lismo);
%mortmodelssub(arthglau,cc,female,m,0,cov=race_db race_dh race_da race_do race_dn  dualmo lismo cc_:);

/* Triple difference with mortality */

data &tempwork..mortalityddd;
	set &tempwork..plwd_mort1 (in=a) &tempwork..arthglau_mort1 (in=b) ;

	* plwd;
	plwd=a;

	*plwd*ffs;
	plwdffs=plwd*ffs;

run;

proc means data=&tempwork..mortalityddd noprint;
	class plwd ffs ipinqtr0;
	var female race_d: age3y: cc: surv ;
	output out=&tempwork..mortddd_samp sum()= mean()= /autoname;
run;

proc export data=&tempwork..mortddd_samp
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_samp";
run;

%macro dddmortmodels(out,cov=);
* full sample;
ods output parameterestimates=&tempwork..mortddd_&out.est;
ods output oddsratios=&tempwork..mortddd_&out.or;
proc logistic data=&tempwork..mortalityddd;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..mortddd_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.est";
run;

proc export data=&tempwork..mortddd_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.or";
run;

* sample with hospitalization in qtr 0;
ods output parameterestimates=&tempwork..mortdddip_&out.est;
ods output oddsratios=&tempwork..mortdddip_&out.or;
proc logistic data=&tempwork..mortalityddd;
	where ipinqtr0=1;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..mortdddip_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortdddip_&out.est";
run;

proc export data=&tempwork..mortdddip_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortdddip_&out.or";
run;
%mend;


%dddmortmodels(base);
%dddmortmodels(ses,cov=dualmo lismo);
%dddmortmodels(cc,cov=dualmo lismo cc_:);



%macro dddmortmodelssub(out,subgroup,outsub,val,cov=);
* full sample;
ods output parameterestimates=&tempwork..mortddd_&out.est&outsub.;
ods output oddsratios=&tempwork..mortddd_&out.or&outsub.;
proc logistic data=&tempwork..mortalityddd;
	where &subgroup.=&val.;
	class age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..mortddd_&out.est&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.est&outsub.";
run;

proc export data=&tempwork..mortddd_&out.or&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.or&outsub.";
run;

* sample with hospitalization in qtr 0;
ods output parameterestimates=&tempwork..mortdddip_&out.est&outsub.;
ods output oddsratios=&tempwork..mortdddip_&out.or&outsub.;
proc logistic data=&tempwork..mortalityddd;
	where ipinqtr0=1 and &subgroup.=&val.;
	class age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..mortdddip_&out.est&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortdddip_&out.est&outsub.";
run;

proc export data=&tempwork..mortdddip_&out.or&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortdddip_&out.or&outsub.";
run;
%mend;

%dddmortmodelssub(base,race_dw,w,1,cov=female);
%dddmortmodelssub(ses,race_dw,w,1,cov=female dualmo lismo);
%dddmortmodelssub(cc,race_dw,w,1,cov=female dualmo lismo cc_:);

%dddmortmodelssub(base,race_db,b,1,cov=female);
%dddmortmodelssub(ses,race_db,b,1,cov=female dualmo lismo);
%dddmortmodelssub(cc,race_db,b,1,cov=female dualmo lismo cc_:);

%dddmortmodelssub(base,race_dh,h,1,cov=female);
%dddmortmodelssub(ses,race_dh,h,1,cov=female dualmo lismo);
%dddmortmodelssub(cc,race_dh,h,1,cov=female dualmo lismo cc_:);

%dddmortmodelssub(base,race_da,a,1,cov=female);
%dddmortmodelssub(ses,race_da,a,1,cov=female dualmo lismo);
%dddmortmodelssub(cc,race_da,a,1,cov=female dualmo lismo cc_:);

%dddmortmodelssub(base,race_dn,n,1,cov=female);
%dddmortmodelssub(ses,race_dn,n,1,cov=female dualmo lismo);
%dddmortmodelssub(cc,race_dn,n,1,cov=female dualmo lismo cc_:);

%dddmortmodelssub(base,race_do,o,1,cov=female);
%dddmortmodelssub(ses,race_do,o,1,cov=female dualmo lismo);
%dddmortmodelssub(cc,race_do,o,1,cov=female dualmo lismo cc_:);

%dddmortmodelssub(base,female,f,1,cov=race_db race_dh race_da race_do race_dn );
%dddmortmodelssub(ses,female,f,1,cov=race_db race_dh race_da race_do race_dn dualmo lismo);
%dddmortmodelssub(cc,female,f,1,cov=race_db race_dh race_da race_do race_dn dualmo lismo cc_:);

%dddmortmodelssub(base,female,m,0,cov=race_db race_dh race_da race_do race_dn );
%dddmortmodelssub(ses,female,m,0,cov=race_db race_dh race_da race_do race_dn dualmo lismo);
%dddmortmodelssub(cc,female,m,0,cov=race_db race_dh race_da race_do race_dn dualmo lismo cc_:);


/* Add location of dx as covariate */

data &tempwork..ffsplwdinc &tempwork..ffsarthglauinc &tempwork..maplwdinc &tempwork..maarthglauinc;
	set &tempwork..mortalityddd;
	inc=max(first_adrddx,first_arthglau);
	format inc mmddyy10.;
	if ffs=1 then do;
		if plwd=1 then output &tempwork..ffsplwdinc;
		else output &tempwork..ffsarthglauinc;
	end;
	else do;
		if plwd=1 then output &Tempwork..maplwdinc;
		else output &tempwork..maarthglauinc;
	end;
	keep bene_id inc ffs plwd;
run;

* SQL to pull;
proc sql;
	create table &tempwork..ffsplwdinc1 as
	select x.*, y.*,(find(y.claim_types,'1')) as ipincdx
	from &tempwork..ffsplwdinc as x left join demdx.dementia_dt_1999_2020 (keep=bene_id demdx_dt claim_types demdx: where=(year(demdx_dt)=2017)) as y
	on x.bene_id=y.bene_id and x.inc=y.demdx_dt;
quit;

proc sql;
	create table &tempwork..maplwdinc1 as
	select x.*, y.*,(find(y.claim_types,'1')) as ipincdx
	from &tempwork..maplwdinc as x left join demdx.dementia_dt_ma15_18 (keep=bene_id clm_thru_dt claim_types demdx: where=(year(clm_thru_dt)=2017)) as y
	on x.bene_id=y.bene_id and x.inc=y.clm_thru_dt;
quit;

proc sql;
	create table &tempwork..ffsarthglauinc1 as
	select x.*, y.*, (find(y.clm_typ,'1')) as ipincdx
	from &tempwork..ffsarthglauinc as x left join &tempwork..arthglau_dx_2015_2018 (keep=bene_id arthglaudx_dt clm_typ arthglaudx: where=(year(arthglaudx_dt)=2017)) as y
	on x.bene_id=y.bene_id and x.inc=y.arthglaudx_dt;
quit;

proc sql;
	create table &tempwork..maarthglauinc1 as
	select x.*, y.clm_typ,y.arthglaudx1,(find(y.clm_typ,'1')) as ipincdx
	from &tempwork..maarthglauinc as x left join &tempwork..arthglaudx_ma15_18(keep=bene_id arthglaudx_dt clm_typ arthglaudx: where=(year(arthglaudx_dt)=2017)) as y
	on x.bene_id=y.bene_id and x.inc=y.arthglaudx_dt;
quit;

* Stack and compare;
data &tempwork..ipincdx;
	set &tempwork..ffsplwdinc1 &tempwork..maplwdinc1 
		&tempwork..ffsarthglauinc1 (rename=(clm_typ=claim_types)) 
		&tempwork..maarthglauinc1 (rename=(clm_typ=claim_types));
run;

proc means data=&tempwork..ipincdx noprint;
	class plwd ffs;
	var ipincdx;
	output out=&tempwork..ipincdx_stats mean()=;
run;

proc freq data=&tempwork..ipincdx noprint;
	where plwd=1;
	table ffs*ipincdx / out=&tempwork..ipincdx_plwd_freq outpct;
	table ffs*claim_types / out=&tempwork..clmtyp_plwd_freq outpct;
run;

proc freq data=&tempwork..ipincdx noprint;
	where plwd=0;
	table ffs*ipincdx / out=&tempwork..ipincdx_arthglau_freq outpct;
	table ffs*claim_types / out=&tempwork..clmtyp_arthglau_freq outpct;
run;

/* Get primary diagnoses from the hospitalization */

data &tempwork..ffsip;
	set rif2017.inpatient_claims_01-rif2017.inpatient_claims_12;
	keep bene_id clm_thru_dt admtg_dgns_cd prncpal_dgns_cd icd_dgns_cd:;
run;

proc sql;
	create table &tempwork..ffsplwdip_prncpal as
	select x.*, y.*
	from &tempwork..ffsplwdinc1 (where=(find(claim_types,'1'))) as x left join &tempwork..ffsip as y 
	on x.bene_id=y.bene_id and x.inc=y.clm_thru_dt;
quit;

proc sql;
	create table &tempwork..maplwdip_prncpal as
	select x.*, y.*
	from &tempwork..maplwdinc1 (where=(find(claim_types,'1'))) as x left join enrfpl17.ip_base_enc (keep=bene_id clm_thru_dt admtg_dgns_cd prncpal_dgns_cd icd_dgns_cd:) as y 
	on x.bene_id=y.bene_id and x.inc=y.clm_thru_dt;
quit;

* Check that the dx is on the claim;
data &tempwork..ffsplwdip_prncpal1;
	set &tempwork..ffsplwdip_prncpal;
	array demdx [*] demdx1-demdx26;
	array icd_dgns_cd [*] icd_dgns_cd:;
	do i=1 to dim(demdx);
		if demdx[i] ne "" then do j=1 to dim(icd_dgns_cd);
			if demdx[i]=icd_dgns_cd[j] then found=1;
		end;
	end;
	if found ne 1 then delete;
run;

data &tempwork..maplwdip_prncpal1;
	set &tempwork..maplwdip_prncpal;
	array demdx [*] demdx1-demdx26;
	array icd_dgns_cd [*] icd_dgns_cd:;
	do i=1 to dim(demdx);
		if demdx[i] ne "" then do j=1 to dim(icd_dgns_cd);
			if demdx[i]=icd_dgns_cd[j] then found=1;
		end;
	end;
	if found ne 1 then delete;
run;

proc freq data=&tempwork..ffsplwdip_prncpal1 order=freq noprint;
	table admtg_dgns_cd / out=&tempwork..ffs_admtg;
	table prncpal_dgns_cd / out=&tempwork..ffs_prncpal;
	table icd_dgns_cd1 / out=&tempwork..ffs_icd;
run;

proc freq data=&tempwork..maplwdip_prncpal1 order=freq noprint;
	table admtg_dgns_cd / out=&tempwork..ma_admtg;
	table prncpal_dgns_cd / out=&tempwork..ma_prncpal;
	table icd_dgns_cd1 / out=&tempwork..ma_icd;
run;

%macro locexport(data);
proc export data=&tempwork..&data
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/inc_location.xlsx"
	dbms=xlsx
	replace;
	sheet="&data";
run;
%mend;

%locexport(ma_admtg);
%locexport(ma_prncpal);
%locexport(ma_icd);
%locexport(ffs_admtg);
%locexport(ffs_prncpal);
%locexport(ffs_icd);
%locexport(ipincdx_stats);
%locexport(ipincdx_plwd_freq);
%locexport(clmtyp_plwd_freq);
%locexport(ipincdx_arthglau_freq);
%locexport(clmtyp_arthglau_freq);

* Add to mortality results and run those again;
proc sort data=&tempwork..ipincdx; by bene_id; run;

proc means data=&tempwork..ipincdx noprint nway;
	class bene_id;
	output out=&tempwork..ipincdx_bene (drop=_type_ _freq_) max(ipincdx)=;
run;

/* Create perm */

data &outlib..ipincdx_bene;
	set &tempwork..ipincdx_bene;
run;
 
/* DD */

proc sort dtaa=&tempwork..plwd_mort; by bene_id; run;

data &tempwork..plwd_mort_loc;
	merge &tempwork..plwd_mort (in=a) maffs.ipincdx_bene (in=b keep=bene_id ipincdx);
	by bene_id;
	if a;
run;

%let cond=plwd;
%let out=loc;
%let cov=dualmo lismo cc_: ipincdx;
ods output parameterestimates=&tempwork..&cond._&out.est;
ods output oddsratios=&tempwork..&cond._&out.or;
proc logistic data=&tempwork..&cond._mort_loc;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..&cond._&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.est";
run;

proc export data=&tempwork..&cond._&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.or";
run;

%macro mortmodelssubip(cond,out,subgroup,outsub,val,cov=);
ods output parameterestimates=&tempwork..&cond._&out.est&outsub.;
ods output oddsratios=&tempwork..&cond._&out.or&outsub.;
proc logistic data=&tempwork..&cond._mort_loc;
	where &subgroup.=&val.;
	class age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..&cond._&out.est&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.est&outsub.";
run;

proc export data=&tempwork..&cond._&out.or&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.or&outsub.";
run;
%mend;

%mortmodelssubip(plwd,loc,race_dw,w,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(plwd,loc,race_db,b,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(plwd,loc,race_dh,h,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(plwd,loc,race_da,a,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(plwd,loc,race_dn,n,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(plwd,loc,race_do,o,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(plwd,loc,female,f,1,cov=race_db race_dh race_da race_do race_dn  dualmo lismo cc_: ipincdx);
%mortmodelssubip(plwd,loc,female,m,0,cov=race_db race_dh race_da race_do race_dn  dualmo lismo cc_: ipincdx);

%mortmodelssubip(arthglau,loc,race_dw,w,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(arthglau,loc,race_db,b,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(arthglau,loc,race_dh,h,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(arthglau,loc,race_da,a,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(arthglau,loc,race_dn,n,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(arthglau,loc,race_do,o,1,cov=female dualmo lismo cc_: ipincdx);
%mortmodelssubip(arthglau,loc,female,f,1,cov=race_db race_dh race_da race_do race_dn  dualmo lismo cc_: ipincdx);
%mortmodelssubip(arthglau,loc,female,m,0,cov=race_db race_dh race_da race_do race_dn  dualmo lismo cc_: ipincdx);

/* DDD */
proc sort data=&tempwork..mortalityddd out=mortalityddd; by bene_id; run;

data &tempwork..mortalityddd_loc;
	merge mortalityddd (in=a) &outlib..ipincdx_bene (in=b keep=bene_id ipincdx);
	by bene_id;
run;

* full sample;
%let out=loc;
%let cov=dualmo lismo cc_: ipincdx;
ods output parameterestimates=&tempwork..mortddd_&out.est;
ods output oddsratios=&tempwork..mortddd_&out.or;
proc logistic data=&tempwork..mortalityddd_loc;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..mortddd_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.est";
run;

proc export data=&tempwork..mortddd_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.or";
run; 

%macro dddmortmodelssubip(out,subgroup,outsub,val,cov=);
* full sample;
ods output parameterestimates=&tempwork..mortddd_&out.est&outsub.;
ods output oddsratios=&tempwork..mortddd_&out.or&outsub.;
proc logistic data=&tempwork..mortalityddd_loc;
	where &subgroup.=&val.;
	class age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..mortddd_&out.est&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.est&outsub.";
run;

proc export data=&tempwork..mortddd_&out.or&outsub.
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.or&outsub.";
run;
%mend;

%dddmortmodelssubip(loc,race_dw,w,1,cov=female dualmo lismo cc_: ipincdx);
%dddmortmodelssubip(loc,race_db,b,1,cov=female dualmo lismo cc_: ipincdx);
%dddmortmodelssubip(loc,race_dh,h,1,cov=female dualmo lismo cc_: ipincdx);
%dddmortmodelssubip(loc,race_da,a,1,cov=female dualmo lismo cc_: ipincdx);
%dddmortmodelssubip(loc,race_dn,n,1,cov=female dualmo lismo cc_: ipincdx);
%dddmortmodelssubip(loc,race_do,o,1,cov=female dualmo lismo cc_: ipincdx);
%dddmortmodelssubip(loc,female,f,1,cov=race_db race_dh race_da race_do race_dn dualmo lismo cc_: ipincdx);
%dddmortmodelssubip(loc,female,m,0,cov=race_db race_dh race_da race_do race_dn dualmo lismo cc_: ipincdx);
