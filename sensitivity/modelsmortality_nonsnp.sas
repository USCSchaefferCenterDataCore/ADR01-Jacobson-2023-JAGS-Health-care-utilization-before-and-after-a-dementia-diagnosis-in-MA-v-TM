/*********************************************************************************************/
title1 'Exclude SNP';

* Author: PF;
* Purpose: Run mortality analysis excluding SNP;
* Input: ffs_mocd2, ma_mocd2_nonsnp;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

data plwd_mortnonsnp;
	set &outlib..ffs_mocd2 (in=a where=(mosfrmplwd=0) keep=bene_id first_adrddx death_date age3y2-age3y9 female race_d: cc_: dualmo lismo mosfrmplwd)
		&tempwork..ma_mocd2_nonsnp (in=b where=(mosfrmplwd=0) keep=bene_id first_adrddx death_date age3y2-age3y9 female race_d: cc_: dualmo lismo mosfrmplwd);

	ffs=a;

	* month of first date;
	month=month(first_adrddx);
	year=year(first_adrddx);

	* surv;
	surv=0;
	if death_date=. or intck('day',first_adrddx,death_date)>=365 then surv=1;

run;

data arthglau_mortnonsnp;
	set &outlib..ffs_mocd2 (in=a where=(mosfrmarthglau=0) keep=bene_id first_arthglau death_date age3y2-age3y9 female race_d: cc_: dualmo lismo mosfrmarthglau)
		&tempwork..ma_mocd2_nonsnp (in=b where=(mosfrmarthglau=0) keep=bene_id first_arthglau death_date age3y2-age3y9 female race_d: cc_: dualmo lismo mosfrmarthglau);

	ffs=a;

	* month of first date;
	month=month(first_arthglau);
	year=year(first_arthglau);

	* surv;
	surv=0;
	if death_date=. or intck('day',first_arthglau,death_date)>=365 then surv=1;

run;

proc sort data=plwd_mortnonsnp; by bene_id year month; run;
proc sort data=arthglau_mortnonsnp; by bene_id year month; run;

data plwd_mortnonsnp1;
	merge plwd_mortnonsnp (in=a) maffs.ma_bene_ip1518 (in=b rename=(ipcount=ipcount_ma)) maffs.ffs_bene_ip1518 (in=c rename=(ipcount=ipcount_ffs));
	by bene_id year month;
	if a;
	ipinqtr0=(b or c);
run;

data arthglau_mortnonsnp1;
	merge arthglau_mortnonsnp (in=a) maffs.ma_bene_ip1518 (in=b rename=(ipcount=ipcount_ma)) maffs.ffs_bene_ip1518 (in=c rename=(ipcount=ipcount_ffs));
	by bene_id year month;
	if a;
	ipinqtr0=(b or c);
run;

%macro mortmodelsnonsnp(cond,out,cov=);
ods output parameterestimates=&tempwork..&cond._&out.est;
ods output oddsratios=&tempwork..&cond._&out.or;
proc logistic data=&cond._mortnonsnp1;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..&cond._&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.est";
run;

proc export data=&tempwork..&cond._&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond._&out.cor";
run;

* Sample with IP in month 0;
ods output parameterestimates=&tempwork..&cond.ip_&out.est;
ods output oddsratios=&tempwork..&cond.ip_&out.or;
proc logistic data=&cond._mortnonsnp1;
	where ipinqtr0=1;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs &cov.;
run;

proc export data=&tempwork..&cond.ip_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond.ip_&out.est";
run;

proc export data=&tempwork..&cond.ip_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/models_mortality_c.xlsx"
	dbms=xlsx
	replace;
	sheet="&cond.ip_&out.or";
run;
%mend;

%mortmodelsnonsnp(plwd,base_nonsnp);
%mortmodelsnonsnp(plwd,ses_nonsnp,cov=dualmo lismo);
%mortmodelsnonsnp(plwd,cc_nonsnp,cov=dualmo lismo cc_:);

%mortmodelsnonsnp(arthglau,base_nonsnp);
%mortmodelsnonsnp(arthglau,ses_nonsnp,cov=dualmo lismo);
%mortmodelsnonsnp(arthglau,cc_nonsnp,cov=dualmo lismo cc_:);


/* Triple difference with mortality */
data mortalitydddnonsnp;
	set plwd_mortnonsnp1 (in=a) arthglau_mortnonsnp1 (in=b) ;

	* plwd;
	plwd=a;

	*plwd*ffs;
	plwdffs=plwd*ffs;

run;

proc means data=mortalitydddnonsnp noprint;
	class plwd ffs ipinqtr0;
	var female race_d: age3y: cc: surv;
	output out=&tempwork..mortddd_sampnonsnp sum()= mean()= /autoname;
run;

proc export data=&tempwork..mortddd_sampnonsnp
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_sampnonsnp";
run;

%macro dddmortmodelsnonsnp(out,cov=);
* full sample;
ods output parameterestimates=&tempwork..mortddd_&out.est;
ods output oddsratios=&tempwork..mortddd_&out.or;
proc logistic data=mortalitydddnonsnp;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..mortddd_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.est";
run;

proc export data=&tempwork..mortddd_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="mortddd_&out.or";
run;

* sample with hospitalization in qtr 0;
ods output parameterestimates=&tempwork..mortdddip_&out.est;
ods output oddsratios=&tempwork..mortdddip_&out.or;
proc logistic data=mortalitydddnonsnp;
	where ipinqtr0=1;
	class female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov. / desc param=reference;
	model surv=female race_db race_dh race_da race_do race_dn age3y2-age3y9 ffs plwd plwdffs &cov.;
run;

proc export data=&tempwork..mortdddip_&out.est
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="mortdddip_&out.est";
run;

proc export data=&tempwork..mortdddip_&out.or
	outfile="&rootpath./Projects/Programs/MAFFSpilot/exports/dddmodels_mortality_nonsnp.xlsx"
	dbms=xlsx
	replace;
	sheet="mortdddip_&out.or";
run;
%mend;

%dddmortmodelsnonsnp(base_nonsnp);
%dddmortmodelsnonsnp(ses_nonsnp,cov=dualmo lismo);
%dddmortmodelsnonsnp(cc_nonsnp,cov=dualmo lismo cc_:);
